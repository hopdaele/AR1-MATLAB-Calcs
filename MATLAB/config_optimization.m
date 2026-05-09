% -------------------------------------------------------------------------
% FSUK 2026 BATTERY PACK OPTIMIZER (Molicel P30B)
% -------------------------------------------------------------------------
% This script iterates through all possible Series (S) and Parallel (P) 
% combinations to find the optimal pack configuration that strictly 
% complies with FSUK/FSG 2026 safety rules.
% -------------------------------------------------------------------------
clc; clear; close all;

% 1. FSUK 2026 RULEBOOK CONSTRAINTS
% -------------------------------------------------------
RULE_V_MAX_TS     = 600;       % [V] Max Tractive System Voltage (EV 4.1.1)
RULE_P_MAX        = 80000;     % [W] Max Power drawn from accumulator (EV 8.4.1)
RULE_V_SEG_MAX    = 120;       % [V] Max Voltage per Segment (EV 5.3.2)
RULE_E_SEG_MAX_MJ = 6.0;       % [MJ] Max Energy per Segment (EV 5.3.2)
RULE_M_SEG_MAX    = 12.0;      % [kg] Max Mass per Segment (EV 5.3.2)
% Note: Mass limit applies to the segment stack weight, usually cells + busbars.

% 2. CELL SPECIFICATIONS (Molicel P30B)
% -------------------------------------------------------
C_cap_Ah  = 3.0;               % Capacity [Ah]
C_V_nom   = 3.6;               % Nominal Voltage [V]
C_V_max   = 4.2;               % Max Voltage [V] (Charge cutoff)
C_V_min   = 2.5;               % Min Voltage [V] (Discharge cutoff)
C_I_cont  = 30;                % Continuous Current [A]
C_I_peak  = 60;                % Peak Current (Pulse) [A]
C_R_dc    = 0.017;             % DC Internal Resistance [Ohm]
C_Mass    = 0.070;             % Cell Mass [kg] (approx includes holder overhead)

% Derived Cell Energy (for segment limits)
C_E_Wh    = C_cap_Ah * C_V_nom; 
C_E_MJ    = C_E_Wh * 3600 / 1e6; % Convert Wh to MJ

% 3. OPTIMIZATION SEARCH SPACE
% -------------------------------------------------------
S_range = 90:142;  % Search 90s to 142s (Max 142*4.2 = 596V)
P_range = 3:10;    % Search 3p to 10p

valid_configs = [];

for S = S_range
    for P = P_range
        
        % --- A. CHECK TOTAL PACK RULES ---
        V_pack_max = S * C_V_max;
        V_pack_nom = S * C_V_nom;
        
        if V_pack_max > RULE_V_MAX_TS
            continue; % Exceeds 600V limit
        end
        
        % --- B. FIND VALID SEGMENTATION (The "Module" Design) ---
        % We must divide S into N segments such that each segment < 120V
        % Minimum segments required based on voltage:
        min_seg_v = ceil(V_pack_max / RULE_V_SEG_MAX);
        
        % We iterate to find a divider that works (integer split)
        found_valid_segmentation = false;
        best_num_seg = 0;
        
        for num_seg = min_seg_v:12 % Try cutting pack into 5, 6, 7... parts
            if mod(S, num_seg) == 0
                % Configuration is physically divisible
                s_per_seg = S / num_seg;
                
                % Check Segment Constraints
                Seg_V_max = s_per_seg * C_V_max;
                Seg_Cells = s_per_seg * P;
                Seg_Energy_MJ = Seg_Cells * C_E_MJ;
                Seg_Mass_kg = Seg_Cells * C_Mass;
                
                if (Seg_V_max <= RULE_V_SEG_MAX) && ...
                   (Seg_Energy_MJ <= RULE_E_SEG_MAX_MJ) && ...
                   (Seg_Mass_kg <= RULE_M_SEG_MAX)
               
                    found_valid_segmentation = true;
                    best_num_seg = num_seg;
                    best_s_seg = s_per_seg;
                    break; % Stop at the lowest valid segment count (simplest BMS)
                end
            end
        end
        
        if ~found_valid_segmentation
            continue; % This S/P combo cannot be legally segmented
        end
        
        % --- C. PERFORMANCE CALCULATION (At 80kW Limit) ---
        R_pack = (S * C_R_dc) / P;
        
        % Current required to output 80kW at Nominal Voltage
        % P_load = V_term * I = (V_oc - I*R) * I
        % 0 = -R*I^2 + V_oc*I - P_load
        % Quadratic formula for I:
        a_quad = R_pack;
        b_quad = -V_pack_nom;
        c_quad = RULE_P_MAX;
        
        delta = b_quad^2 - 4*a_quad*c_quad;
        
        if delta < 0
            continue; % Cannot physically support 80kW (Voltage collapse)
        end
        
        I_req_80kW = (-b_quad - sqrt(delta)) / (2*a_quad);
        
        % Current per cell check
        I_cell_req = I_req_80kW / P;
        if I_cell_req > C_I_peak
            continue; % Exceeds cell capabilities
        end
        
        % Efficiency & Energy
        Power_Loss_kW = (I_req_80kW^2 * R_pack) / 1000;
        Efficiency_Pct = (RULE_P_MAX / (RULE_P_MAX + (Power_Loss_kW*1000))) * 100;
        Total_Energy_kWh = (S * P * C_cap_Ah * C_V_nom) / 1000;
        Total_Mass_Cells = S * P * C_Mass;
        
        % --- D. SAVE RESULT ---
        % Columns: [S, P, Segments, S_per_Seg, Eff%, Energy_kWh, Cell_Amps, Seg_MJ]
        valid_configs = [valid_configs; ...
            S, P, best_num_seg, best_s_seg, Efficiency_Pct, Total_Energy_kWh, I_cell_req, Seg_Energy_MJ];
    end
end

% 4. RANKING & DISPLAY
% -------------------------------------------------------
% Convert to Table
T = array2table(valid_configs, 'VariableNames', ...
    {'Total_S', 'Total_P', 'Num_Segments', 'S_per_Seg', 'Efficiency', 'Pack_kWh', 'Cell_Current_A', 'Seg_Energy_MJ'});

% Sort: Primary = Efficiency (descending), Secondary = Energy (descending)
T = sortrows(T, {'Efficiency', 'Pack_kWh'}, {'descend', 'descend'});

% Filter for "Endurance Viable" (> 6.5 kWh)
T_viable = T(T.Pack_kWh > 6.5, :);

fprintf('=== FSUK 2026 OPTIMIZED CONFIGURATIONS ===\n');
fprintf('Top 5 Configurations (Sorted by Electrical Efficiency @ 80kW)\n');
disp(head(T_viable, 5));

% Compare Current vs Optimized
fprintf('\n--- CONFIGURATION COMPARISON ---\n');
curr_idx = find(T.Total_S == 108 & T.Total_P == 6);
if ~isempty(curr_idx)
    fprintf('CURRENT (108s6p): Eff: %.1f%% | Energy: %.1f kWh | Segments: %d (Invalid if > 6MJ/seg)\n', ...
        T.Efficiency(curr_idx), T.Pack_kWh(curr_idx), T.Num_Segments(curr_idx));
else
    fprintf('CURRENT (108s6p): ** ILLEGAL ** (Likely Seg Energy > 6MJ or Mass > 12kg)\n');
end

best_row = T_viable(1,:);
fprintf('OPTIMAL (%ds%dp):   Eff: %.1f%% | Energy: %.1f kWh | Layout: %d Segments of %ds%dp\n', ...
    best_row.Total_S, best_row.Total_P, best_row.Efficiency, best_row.Pack_kWh, ...
    best_row.Num_Segments, best_row.S_per_Seg, best_row.Total_P);

% 5. VISUALIZATION
% -------------------------------------------------------
figure('Name', 'FSUK Pack Optimization');

% Subplot 1: Design Space
subplot(1,2,1);
scatter(T.Total_S, T.Total_P, 50, T.Efficiency, 'filled');
colormap(jet);
c = colorbar; c.Label.String = 'Efficiency @ 80kW (%)';
xlabel('Series Count (S)'); ylabel('Parallel Count (P)');
title('Design Space: Efficiency');
grid on;
hold on;
% Mark optimal
plot(best_row.Total_S, best_row.Total_P, 'rp', 'MarkerSize', 15, 'LineWidth', 2);
text(best_row.Total_S, best_row.Total_P+0.3, ' Optimal', 'Color', 'r', 'FontWeight', 'bold');

% Subplot 2: Heat vs Config
subplot(1,2,2);
% Calculate Heat Loss for Endurance (Average 15kW load approx)
P_avg_endurance = 15000; % 15kW avg
I_avg = P_avg_endurance ./ (T.Total_S * C_V_nom);
Heat_Loss = I_avg.^2 .* ((T.Total_S * C_R_dc) ./ T.Total_P);
scatter(T.Pack_kWh, Heat_Loss, 50, T.Total_S, 'filled');
c2 = colorbar; c2.Label.String = 'Series Count (Voltage)';
xlabel('Pack Energy (kWh)'); ylabel('Est. Heat Generation (W)');
title('Thermal Trade-off: Energy vs Heat');
grid on;