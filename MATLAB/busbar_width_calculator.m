% For a 1sNp battery module using copper busbars

clc; clear;

% inputs 
Np = 22;                 % Number of cells in parallel
I_cell_max = 30;         % Max continuous current per cell (A)
t = 20;                 % Busbar thickness (mm)
k = 1.0;                 % Allowed current density (A/mm^2)

% calcs
% Total current through the parallel busbar
I_total = Np * I_cell_max;

% Required busbar width
w_mm = I_total / (k * t);

% ===== Display Result =====
fprintf('Required parallel busbar width: %.2f mm\n', w_mm);
