% Molicel P30B Pack Power Analysis (FS EV)
% Pack: 108s6p (648 cells total)

clc; clear; close all;

% Cell specifications (datasheet)
V_cell_nom = 3.6;        % V
V_cell_max = 4.2;        % V
I_cell_cont = 30;        % A (continuous)
R_cell = 17e-3;          % Ohms (typical DC IR)

% Pack configuration
S = 108;                 % series
P = 6;                   % parallel

% Derived pack values
V_pack_nom = S * V_cell_nom;
V_pack_max = S * V_cell_max;
I_pack_cont = P * I_cell_cont;

R_group = R_cell / P;          % resistance per parallel group
R_pack = S * R_group;          % total pack resistance

% Current sweep (realistic operating range)
I = linspace(0, I_pack_cont, 300);

% Power calculations
P_nom = V_pack_nom .* I;       % Nominal voltage power
P_max = V_pack_max .* I;       % Max voltage power
P_loss = I.^2 .* R_pack;       % Resistive losses

% === FIGURE 1: Power vs Current ===
figure;
plot(I, P_nom/1000, 'LineWidth', 2); hold on;
plot(I, P_max/1000, '--', 'LineWidth', 2);
xlabel('Pack Current (A)');
ylabel('Power (kW)');
title('Pack Power vs Current (Molicel P30B, 108s6p)');
legend('Nominal Voltage', 'Fully Charged', 'Location', 'northwest');
grid on;

% === FIGURE 2: Power Loss vs Current ===
figure;
plot(I, P_loss/1000, 'r', 'LineWidth', 2);
xlabel('Pack Current (A)');
ylabel('Resistive Loss (kW)');
title('Battery Resistive Loss vs Current');
grid on;

% === FIGURE 3: Net Usable Power ===
P_net = P_nom - P_loss;

figure;
plot(I, P_net/1000, 'LineWidth', 2);
xlabel('Pack Current (A)');
ylabel('Net Power Output (kW)');
title('Net Electrical Power vs Current');
grid on;

% Mark endurance operating points
hold on;
I_endurance = [80 100 120];
P_endurance = V_pack_nom .* I_endurance - I_endurance.^2 .* R_pack;
scatter(I_endurance, P_endurance/1000, 80, 'filled');

% Console output summary
fprintf('--- Pack Summary (Molicel P30B, 108s6p) ---\n');
fprintf('Nominal Voltage: %.1f V\n', V_pack_nom);
fprintf('Max Voltage: %.1f V\n', V_pack_max);
fprintf('Continuous Current: %.0f A\n', I_pack_cont);
fprintf('Continuous Power (Nominal): %.1f kW\n', ...
        V_pack_nom * I_pack_cont / 1000);
fprintf('Peak Power (Fully Charged): %.1f kW\n', ...
        V_pack_max * I_pack_cont / 1000);
fprintf('Pack Resistance: %.3f Ohms\n', R_pack);
