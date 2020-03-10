function [measure_out, lineage_matrix] = copychildren(measure_in, celldata_in, t)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% [measure_out, lineage_matrix] = copychildren(measure_in, celldata_in, t)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% COPYCHILDREN uses lineage information to copy mother trajectories (i.e. prior to division) to any daughter cells.
% Requires a raw matrix of measurements (one measurement per cell), and "CellData" information matrix from MACKtrack.
% CellData info:  [ xy position | cell idx | frame in | frame out | parent | is_edge ]
%
% INPUTS
% measure_in     Measurement data (if cell matrix, each measurement is one cell) to be copied
% celldata_in    CellData information matrix. Can be a cell matrix, with multiple measurements - multidim. cell
%                    matricies will be vectorized
% t              (optional) time vector that corresponds to a measurement matrix (may include non-whole timepoints)
%
% OUTPUTS
% measure_out      Measurement data with copied lineage information
% lineage_matrix   Lineage information for each cell, per timepoint
%
%
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

% Create output measurements (force to be cell if not already)
if ~iscell(measure_in)
    measure_out{1} = measure_in;
    notcell = 1;
else  
    measure_out = measure_in(:);
    notcell = 0;
end

% Grab time vector, if not provided
if nargin<3
    t = 1:size(measure_out{1},2);
end

if size(t,1)>1 && size(t,2)>1 % Ensure t is a vector, not a matrix (default output for some measure modules)
    t_idx = find(size(t)==size(measure_out{1},2));
    if t_idx==1
        t = t(:,1);
    elseif t_idx==2
        t = t(1,:);
    else
        error('Mismatch between input time vector and measurement')
    end
end

% Do copy operation
lineage_matrix = nan(size(measure_out{1}));
sites = unique(celldata_in(:,1));
for idx = 1:length(sites)
    rows = celldata_in(:,1)==sites(idx);
    celldata = celldata_in(rows,:);
    row_idx= find(rows);
    for i = row_idx(:)'
        t_in = (t>=celldata_in(i,3)) & (t<=celldata_in(i,4));
        lineage_matrix(i,t_in) = celldata_in(i,2);      
        if celldata_in(i,5)>0
            t_mom = t<celldata_in(i,3);
            match_row = row_idx(celldata_in(i,5)==celldata(:,2));
            for z = 1:length(measure_out)
                measure_out{z}(i,t_mom) = measure_out{z}(match_row,t_mom);
            end
            lineage_matrix(i,t_mom) = lineage_matrix(match_row,t_mom);
        end
    end
end

% Convert outback back if a matrix was input
if notcell
    measure_out = measure_out{1};
end
