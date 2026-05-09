%% FSAE Tractive System Simulation (Nebraska Drive Cycle)
% Translates telemetry km/h data into battery and motor electrical loads.
clear; clc; close all;

%% 1. Configuration Parameters
% Accumulator (Molicel P30B)
params.pack_s = 28;             % Number of cells in series
params.pack_p = 22;             % Number of cells in parallel
params.cell_ir = 17 / 1000;     % Cell DC Internal Resistance (Ohms)
params.start_soc = 100;         % Starting State of Charge (%)
params.cell_cap_ah = 3.0;       % Nominal capacity per cell (Ah)

% Motor (ME1616)
params.kt = 0.22;               % Torque Constant (Nm/A)
params.gear_ratio = 5.8;        % Final Drive Gear Ratio
params.p_limit_kw = 80.0;       % Max Power Limit (kW)
params.efficiency = 0.92;       % Drivetrain/Inverter Efficiency

% Vehicle
params.tire_radius = 0.4064;    % Tire Radius (m)
params.mass = 350;              % Vehicle Mass including driver (kg)

%% 2. Load Telemetry Data (Nebraska Format)
% Expected CSV columns: [km/h, s, ...]
filename = 'Nebraska2012.csv';
if ~exist(filename, 'file')
    error('File %s not found. Please ensure Nebraska2012.csv is in the path.', filename);
end

data = readmatrix(filename);
v_kmh = data(:, 1);  % Speed in km/h
time = data(:, 2);   % Time in seconds

% Filter out non-finite or negative speeds
valid_idx = isfinite(v_kmh) & (v_kmh >= 0);
v_kmh = v_kmh(valid_idx);
time = time(valid_idx);

%% 3. Pre-compute SoC Lookup (Molicel P30B)
soc_map = [100, 4.20; 90, 4.05; 80, 3.92; 70, 3.82; 60, 3.74; 50, 3.68; ...
           40, 3.62; 30, 3.55; 20, 3.45; 10, 3.20; 0, 2.50];

%% 4. Run Simulation Loop
n = length(v_kmh);
results = struct('batt_v', zeros(n,1), 'batt_i', zeros(n,1), ...
                 'phase_i', zeros(n,1), 'soc', zeros(n,1), 'power_kw', zeros(n,1));

current_soc = params.start_soc;
pack_dcr = (params.cell_ir * params.pack_s) / params.pack_p;
total_cap_ah = params.pack_p * params.cell_cap_ah;
energy_used_ws = 0;

for i = 2:n
    dt = time(i) - time(i-1);
    if dt <= 0, dt = 0.001; end % Prevent division by zero
    
    vel_ms = v_kmh(i) / 3.6;
    rpm = (vel_ms * params.gear_ratio * 60) / (2 * pi * params.tire_radius);
    
    % Open Circuit Voltage
    cell_ocv = interp1(soc_map(:,1), soc_map(:,2), current_soc, 'linear', 'extrap');
    pack_ocv = cell_ocv * params.pack_s;
    
    % Force Calculations (Aero + Acceleration)
    p_aero = 0.5 * 1.225 * 1.2 * (vel_ms^3); % Simple aero drag
    accel = (vel_ms - (v_kmh(i-1)/3.6)) / dt;
    p_accel = params.mass * accel * vel_ms;
    
    p_mech = max(0, p_aero + p_accel);
    p_elec = p_mech / params.efficiency;
    
    % Apply Power Limit
    if p_elec > (params.p_limit_kw * 1000)
        p_elec = params.p_limit_kw * 1000;
    end
    
    % Solve for Battery Current using Quadratic Formula: P = IV - I^2R
    % 0 = R*I^2 - V_ocv*I + P_elec
    a = pack_dcr;
    b = -pack_ocv;
    c = p_elec;
    disc = b^2 - 4*a*c;
    
    if disc >= 0
        batt_i = (-b - sqrt(disc)) / (2*a);
    else
        % Voltage collapse case (drawing too much power)
        batt_i = pack_ocv / (2 * pack_dcr); 
    end
    
    % Voltage and Phase Current
    v_term = pack_ocv - (batt_i * pack_dcr);
    omega_rads = (rpm * 2 * pi) / 60;
    phase_i = (p_elec * params.efficiency) / max(0.1, omega_rads * params.kt);
    
    % Update State
    energy_used_ws = energy_used_ws + (p_elec * dt);
    current_soc = current_soc - (batt_i * dt / 3600 / total_cap_ah) * 100;
    
    % Store Results
    results.batt_v(i) = v_term;
    results.batt_i(i) = batt_i;
    results.phase_i(i) = min(600, phase_i); % Clamp to motor peak
    results.soc(i) = current_soc;
    results.power_kw(i) = p_elec / 1000;
end

%% 5. Visualization
figure('Name', 'FSAE Tractive System Analysis', 'Color', 'w');

% Velocity Profile
subplot(3,1,1);
plot(time, v_kmh, 'LineWidth', 1.5, 'Color', [0 0.447 0.741]);
ylabel('Speed (km/h)');
title('Nebraska Drive Cycle Velocity');
grid on;

% Electrical Loads
subplot(3,1,2);
yyaxis left
plot(time, results.phase_i, 'LineWidth', 1.2, 'DisplayName', 'Phase Current');
hold on;
plot(time, results.batt_i, '--', 'LineWidth', 1.2, 'DisplayName', 'Battery Current');
ylabel('Current (A)');
yyaxis right
plot(time, results.power_kw, 'LineWidth', 1.2, 'DisplayName', 'Power Draw');
ylabel('Power (kW)');
legend('Location', 'best');
title('Motor & Battery Dynamics');
grid on;

% Battery Health
subplot(3,1,3);
yyaxis left
plot(time, results.batt_v, 'LineWidth', 1.5, 'Color', [0.466 0.674 0.188]);
ylabel('Bus Voltage (V)');
yyaxis right
plot(time, results.soc, 'LineWidth', 1.5, 'Color', [0.929 0.694 0.125]);
ylabel('SoC (%)');
xlabel('Time (s)');
title('Accumulator Terminal Voltage & SoC');
grid on;

% Summary Printout
fprintf('--- Simulation Results ---\n');
fprintf('Total Distance: %.2f m\n', trapz(time, v_kmh/3.6));
fprintf('Energy Consumed: %.2f Wh\n', energy_used_ws / 3600);
fprintf('Minimum Voltage: %.1f V\n', min(results.batt_v(2:end)));
fprintf('Peak Battery Current: %.1f A\n', max(results.batt_i));
fprintf('Final SoC: %.2f %%\n', current_soc);