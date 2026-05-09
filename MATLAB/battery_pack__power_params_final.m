clc;
clear;
close all;

f = readtable("C:\Users\Muneeb\Desktop\AUS Racing\Nebraska2012.csv");

Ns = 28;
Np = 22;
Vcell_nom = 3.6;
Rcell = 0.020;
Capacity_Ah = 66;
Capacity_kWh = 6.65;

Vpack_nom = Ns * Vcell_nom;
Rpack = (Ns / Np) * Rcell;

Power_W = f.kW * 1000;
Ipack = Power_W ./ Vpack_nom;

Icell = Ipack ./ Np;
Pheat_cell = (Icell.^2) .* Rcell;
Pheat_pack = (Ipack.^2) .* Rpack;

efficiency = 100 * Power_W ./ (Power_W + Pheat_pack);

time = f.s;
dt = [0; diff(time)];

Ah_used = cumsum(Ipack .* dt) / 3600;
SoC = 100 * (1 - Ah_used / Capacity_Ah);

Energy_per_lap_kWh = (Ah_used(end) * Vpack_nom) / 1000;

x_coords = f.m_2;
y_coords = f.m_3;

dx = diff(x_coords);
dy = diff(y_coords);
segment_dist = sqrt(dx.^2 + dy.^2);

lap_distance_m = sum(segment_dist);
lap_distance_km = lap_distance_m / 1000;

endurance_distance_km = 22;
num_laps = endurance_distance_km / lap_distance_km;

Total_energy_used = num_laps * Energy_per_lap_kWh;
Final_SoC = 100 * (1 - Total_energy_used / Capacity_kWh);

figure;

subplot(3,2,1);
plot(time, Power_W/1000, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Power (kW)');
title('Pack Power vs Time');
grid on;

subplot(3,2,2);
plot(time, Ipack, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Pack Current (A)');
title('Pack Current vs Time');
grid on;

subplot(3,2,3);
plot(time, Pheat_cell, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Per-Cell Heat (W)');
title('Heat per Cell vs Time');
grid on;

subplot(3,2,4);
plot(time, Pheat_pack/1000, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Total Pack Heat (kW)');
title('Total Pack Heat vs Time');
grid on;

subplot(3,2,5);
plot(time, efficiency, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Efficiency (%)');
title('Efficiency vs Time');
grid on;

subplot(3,2,6);
plot(time, SoC, 'LineWidth', 2);
xlabel('Time (s)');
ylabel('SoC (%)');
title('SoC vs Time (Single Lap)');
grid on;
ylim([0 100]);

sgtitle('Battery Pack Analysis – Single Lap');

time_lap = time;
SoC_lap = SoC;

total_time = [];
total_SoC = [];

current_offset = 0;
SoC_offset = 100;

for i = 1:floor(num_laps)
    total_time = [total_time; time_lap + current_offset];
    total_SoC = [total_SoC; SoC_offset - (100 - SoC_lap)];

    current_offset = total_time(end);
    SoC_offset = total_SoC(end);
end

figure;
plot(total_time, total_SoC, 'LineWidth', 2);
xlabel('Time (s)');
ylabel('State of Charge (%)');
title('22 km Endurance SoC Simulation');
grid on;
ylim([0 100]);

figure;
scatter(x_coords, y_coords, 10, f.km_h, 'filled');
title('Track Map with Speed Heatmap (km/h)');
xlabel('X Coordinate (m)');
ylabel('Y Coordinate (m)');
axis equal;
grid on;
box on;
c = colorbar;
c.Label.String = 'Speed (km/h)';

fprintf('\n----- SINGLE LAP RESULTS -----\n');
fprintf('Lap distance: %.3f km\n', lap_distance_km);
fprintf('Energy per lap: %.3f kWh\n', Energy_per_lap_kWh);
fprintf('SoC at end of lap: %.2f %%\n', SoC(end));
fprintf('Average pack current: %.1f A\n', mean(Ipack));
fprintf('Average efficiency: %.2f %%\n', mean(efficiency));

fprintf('\n----- ENDURANCE SIM (22 km) -----\n');
fprintf('Number of laps: %.1f\n', num_laps);
fprintf('Total energy used: %.2f kWh\n', Total_energy_used);
fprintf('Final SoC after 22 km: %.1f %%\n', Final_SoC);
fprintf('Average power during lap: %.1f kW\n', mean(Power_W)/1000);
