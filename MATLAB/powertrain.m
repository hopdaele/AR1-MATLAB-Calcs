clc
clear
close all

%% ==============================
% ACCUMULATOR PARAMETERS
% ==============================

Ns = 28;                 % cells in series
Np = 22;                 % cells in parallel

V_cell_nom = 3.6;        % V
V_cell_max = 4.2;        % V
Cap_cell = 3.0;          % Ah

Vdc_nom = Ns * V_cell_nom;
Vdc_max = Ns * V_cell_max;

Cap_pack = Np * Cap_cell;
Energy_pack_kWh = (Vdc_nom * Cap_pack)/1000;

fprintf("Accumulator nominal voltage: %.1f V\n",Vdc_nom)
fprintf("Accumulator max voltage: %.1f V\n",Vdc_max)
fprintf("Accumulator capacity: %.1f Ah\n",Cap_pack)
fprintf("Accumulator energy: %.2f kWh\n\n",Energy_pack_kWh)

%% ==============================
% SEVCON GEN4 SIZE 6 LIMITS
% ==============================

Idc_cont = 210;      % A RMS
Idc_peak = 550;      % A RMS

%% ==============================
% MOTOR PARAMETERS (ME1616)
% ==============================

Kt = 0.22;           % Nm/A
Ke = 0.026;          % V/RPM

rpm_max = 6000;

eff_motor = 0.92;

%% ==============================
% INVERTER APPROXIMATION
% ==============================

modulation_index = 0.9;

V_phase = modulation_index * Vdc_nom / 2;

%% ==============================
% SPEED LIMIT FROM BACK EMF
% ==============================

rpm_voltage_limit = V_phase / Ke;

fprintf("Voltage limited speed: %.0f RPM\n\n",rpm_voltage_limit)

%% ==============================
% CURRENT RANGE
% ==============================

Idc = linspace(0,Idc_peak,500);

% approximate DC → phase relationship
I_phase = 1.5 .* Idc;

%% ==============================
% TORQUE
% ==============================

Torque = Kt .* I_phase;

%% ==============================
% SPEED RANGE
% ==============================

rpm = linspace(0,rpm_max,500);
omega = rpm .* 2 .* pi ./ 60;

%% ==============================
% CONSTANT TORQUE REGION
% ==============================

T_peak = max(Torque);

Torque_curve = T_peak .* ones(size(rpm));

%% ==============================
% CONSTANT POWER REGION
% ==============================

P_elec_peak = Vdc_nom * Idc_peak;

P_mech_peak = eff_motor * P_elec_peak;

Torque_power_limit = P_mech_peak ./ omega;

Torque_power_limit(1) = T_peak;

Torque_final = min(Torque_curve, Torque_power_limit);

Power_mech = Torque_final .* omega;

%% ==============================
% PLOTS
% ==============================

figure
plot(Idc,Torque,'LineWidth',2)
grid on
xlabel("DC Current (A)")
ylabel("Motor Torque (Nm)")
title("Torque vs DC Current")

figure
plot(rpm,Torque_final,'LineWidth',2)
grid on
xlabel("Motor Speed (RPM)")
ylabel("Torque (Nm)")
title("Torque-Speed Curve")

figure
plot(rpm,Power_mech/1000,'LineWidth',2)
grid on
xlabel("Motor Speed (RPM)")
ylabel("Mechanical Power (kW)")
title("Power-Speed Curve")

%% ==============================
% WHEEL TORQUE (OPTIONAL)
% ==============================

gear_ratio = 4;
drivetrain_eff = 0.95;

Wheel_Torque = Torque_final .* gear_ratio .* drivetrain_eff;

figure
plot(rpm,Wheel_Torque,'LineWidth',2)
grid on
xlabel("Motor Speed (RPM)")
ylabel("Wheel Torque (Nm)")
title("Wheel Torque vs RPM")