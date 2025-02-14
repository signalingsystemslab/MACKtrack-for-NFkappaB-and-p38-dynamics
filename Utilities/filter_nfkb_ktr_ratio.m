function [graph, info, measure] = filter_nfkb_ktr_ratio(id,varargin)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [graph, info, measure] = filter_nfkb_ktr_ratio(id,varargin)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% filter_nfkb_ktr_ratio is a data processing script specialized to process
% data from a nuclear-translocating species (it looks for NFkBdimNuclear and NFkBdimCytoplasm measurements)together with cytoplasmic/nuclear ratio of a second species (e.g. KTR) cell-by-cell.
%
% INPUTS (required):
% id             filename or experiment ID (from Google Spreadsheet specified in "locations.mat")
%
% INPUT PARAMETERS (optional; specify with name-value pairs)
% 'Verbose'         'on' or 'off' - shows non-compacted graphs, e.g.
%                   heatmap including cells to be filtered out, default
%                   is off
% 'MinLifetime'     final frame used to filter for long-lived cells, default set to 100
% 'ConvectionShift' Maximum allowable time-shift between different XYs (to correct for poor mixing), default is 1
% 'MinSize'         minimal allowable nuclear area to exclude debris, etc, default set to 90
% 'StartThreshNFkB'     max allowable starting threshhold to filter out cells
%                   with pre-activated NFkB, default is 2
% 'GraphLimitsNFkB' default is [-0.25 8]
% ...

% OUTPUTS:  
% graph          primary output structure; must specify
%                   1) filtered/processed data (graph.var) 
%                   2) time vector for all images (graph.t) 
%                   3) XY convection adjustment (graph.shift) 
% info           secondary output structure; must specify
%                   1) Y limits for graphing (info.GraphLimits)
%                   2) parameters from loadID.m (info.parameters) 
% measure         full output structure from loadID
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%% Create input parser object (checks if functions is provided with correct inputs), add required params from function input
p = inputParser;
% Required: ID input; checks whether ID input is valid (is a numeric array of only
    % one number, or is a structure array, or if it is a file)
valid_id = @(x) assert((isnumeric(x)&&length(x)==1)||isstruct(x)||exist(x,'file'),...
    'ID input must be spreadsheet ID or full file path');
addRequired(p,'id',valid_id);

% Optional parameters; specifies allowed optional parameters
expectedFlags = {'on','off'};
addParameter(p,'Verbose','off', @(x) any(validatestring(x,expectedFlags)));%checks whether optional name-value argument matches on or off %checks if x matches expectedFlags
addParameter(p,'MinLifetime',109, @isnumeric); %allows adjustment of minimum lifetime
addParameter(p,'MinSize',90); %allows adjustment of minimum size
addParameter (p, 'OnThreshNFkB', 3, @isnumeric); %sigma threshold for determining responders
addParameter (p, 'GraphLimitsNFkB',[-0.25 7],@isnumeric);
addParameter (p, 'OnThreshKTR', 3, @isnumeric);%sigma threshold for determining responders
addParameter (p, 'GraphLimitsKTR',[-0.02,0.35],@isnumeric);
addParameter(p, 'StimulationTimePoint', 13, @isnumeric); % number of unstimulated timepoints to use in baseline calculation, etc
addParameter(p, 'NFkBBackgroundAdjustment', 'on',@(x) any(validatestring(x,expectedFlags))) %option to turn off NFkB fluorescence distribution adjustment
addParameter(p,'NFkBBaselineDeduction', 'on', @(x) any(validatestring(x,expectedFlags))) %option to turn off NFkB baseline deduction
addParameter(p,'NFkBBaselineAdjustment', 'on', @(x) any(validatestring(x,expectedFlags))) %option to turn off adjusment of NFkB trajectories with correction factor for fluorescence drop derived from Mock experiments
addParameter(p, 'BrooksBaseline', 'off', @(x) any(validatestring(x,expectedFlags)))
addParameter(p, 'FramesPerHour', 12, @isnumeric)
addParameter(p,'KTRBaselineDeduction', 'on', @(x) any(validatestring(x,expectedFlags))) %option to turn off NFkB baseline deduction
addParameter(p,'KTRBaselineAdjustment', 'on', @(x) any(validatestring(x,expectedFlags))) %option to turn off adjusment of KTR trajectories with correction factor for fluorescence drop derived from Mock experiments

addParameter(p, 'IncludeKTR', 'on',@(x)any(validatestring(x, expectedFlags)));


% Parse parameters, assign to variables
parse(p,id, varargin{:}) 
if strcmpi(p.Results.Verbose,'on') 
    verbose_flag = 1; %sets verbose_flag to 1 if input parameter Verbose is set to 'on'
else
    verbose_flag = 0;
end

% Set display/filtering parameters
MinLifetime = p.Results.MinLifetime; %pulls number for MinLifetime from input parameters
area_thresh = p.Results.MinSize; % Minimum nuclear area (keeps from including small/junk objects)
StimulationTimePoint = p.Results.StimulationTimePoint;
%% Load AllMeasurements data
[measure, info] = loadID(id);
info.ImageExprNFkB = info.parameters.nfkbdimModule.ImageExpr; %this refers to ImageExpr in nfkbdimModule in parameters of AllMeasurement file

if strcmpi(p.Results.IncludeKTR,'on')
    info.ImageExprKTR = info.parameters.ktrModule.ImageExpr;
end

info.GraphLimitsNFkB = p.Results.GraphLimitsNFkB; % Min/max used in graphing
info.GraphLimitsKTR = p.Results.GraphLimitsKTR; % Min/max used in graphing
info.OnThreshNFkB = p.Results.OnThreshNFkB;
info.OnThreshKTR = p.Results.OnThreshKTR;
info.parameters.FramesPerHour = p.Results.FramesPerHour;

%% Filtering
robuststd = @(distr, cutoff) nanstd(distr(distr < (nanmedian(distr)+cutoff*nanstd(distr)))); %standard deviation

% For running eg Supriya's AllMeasurements files, rename fields as
% necessary
if ~isfield(measure,'NFkBdim_Nuclear')
    measure.NFkBdim_Nuclear = measure.NFkBdimNuclear;
end
if ~isfield(measure,'NFkBdim_Cyto_full')
    measure.NFkBdim_Cyto_full= measure.NFkBdimCytoplasm;
end
if ~isfield(info.parameters,'adj_distr_NFkBdim')
    info.parameters.adj_distr_NFkBdim= info.parameters.adj_distr;
end
if ~isfield(measure,'MeanNuc1')
    measure.MeanNuc1= measure.MeanIntensityNuc;
end

% Filtering, part 1 cell fate and cytoplasmic intensity
droprows = []; %creates an empty matrix/array
droprows = [droprows, sum(isnan(measure.NFkBdim_Nuclear(:,1:StimulationTimePoint)),2)>2]; % Use only cells existing @ expt start %concatenates a set of 1 or 0 value to droprow matrix for each cells depending on whether there are more than 2 NaN values in nuclear NFkB levels within baseline TPs
droprows = [droprows, sum(isnan(measure.NFkBdim_Nuclear(:,1:MinLifetime)),2)>3]; % Use only long-lived cells %concatenates a set of 1 or 0 value to droprow matrix for each cells depening on whether there are more than 3 NaN values in nuclear NFkB levels within minimum lifetime
droprows = [droprows, sum(measure.NFkBdim_Cyto_full(:,1:StimulationTimePoint)==0,2)>0]; % Exclude Very dim cells %concatenates a set of 1 or 0 value to droprow matrix for each cells depening on whether there are more than 0 nfkb cytoplasmic values in baseline TPs that are equal to 0

if strcmpi(p.Results.IncludeKTR,'on')
    droprows = [droprows, ((nanmean(measure.KTR_nuc1(:,1:StimulationTimePoint), 2)< prctile(nanmean(measure.KTR_nuc1(:,1:StimulationTimePoint), 2), 5)) | (nanmean(measure.KTR_nuc1(:,1:StimulationTimePoint), 2)> prctile(nanmean(measure.KTR_nuc1(:,1:StimulationTimePoint), 2), 95)))]; %filters cells with very low or high KTR expression
end

nfkb = measure.NFkBdim_Nuclear(:,:); %nfkb is defined as NFkB nuclear measurement from NFkBdim module

%This does an adjustment for background fluorescence to make experiments comparable; option to turn

if strcmpi(p.Results.NFkBBackgroundAdjustment,'on')
    nfkb = nfkb/mean(info.parameters.adj_distr_NFkBdim(2,:)); %nfkb is re-defined of nfkb divided by mean of second row of adj_distr 
end   

%NFkB baseline deduction, simply deducting mean of unstimulated timepoints per cell
    nfkb_no_base_ded = nfkb;    
    
    % Option to use Brooks' baseline deduction (baseline or minimum values later in trajectories used as baseline, whichever is smaller), eg for experiments with preactivation 
    if strcmpi(p.Results.BrooksBaseline ,'on')
            baseline_length_nfkb = size(measure.NFkBdim_Nuclear,2); % Endframe for baseline calculation (use entire vector), baseline length is the size of the rows, i.e. number of timepoints 
            nfkb_smooth = nan(size(nfkb)); %NaN array of same size as nfkb is created, for created smoothed trajectory
            for i = 1:size(nfkb,1)
                nfkb_smooth(i,~isnan(nfkb(i,:))) = medfilt1(nfkb(i,~isnan(nfkb(i,:))),3); %replaces every element in nfkb_smooth that is not NaN in corresponding nfkb position with a 3rd order median filtered version 
            end
            nfkb_min = prctile(nfkb_smooth(:,1:baseline_length_nfkb),5,2); %calculates the 5th percentile along rows of the nfkb smoothed trajectory up to the baseline length, Ade's version uses 2,2 instead of 5,2
            nfkb_baseline = nanmin([nanmin(nfkb(:,1:4),[],2),nfkb_min],[],2); %nfkb baseline is defined as minimum of (nfkb_min and the minimum of nfkb at the first four timepoints)
    else
        
    nfkb_baseline = nanmean(nfkb(:,1:StimulationTimePoint),2); %baseline is determined from 1st to 13th timepoint 
    end
    
if strcmpi(p.Results.NFkBBaselineDeduction,'on')
    nfkb =  nfkb - nfkb_baseline; % nfkb activity is defined as baseline - fluorescence measurement
end 

%NFkB Baseline shift adjustment based on general mock values
if strcmpi(p.Results.NFkBBaselineAdjustment,'on')
    home_folder = mfilename('fullpath'); % Load locations (for images and output data)%mfilename returns path of currently running code
    slash_idx = strfind(home_folder,filesep); %looks for system-specific file separator in home_folder
    OneDrivePath = getenv('OneDrive');
    load([OneDrivePath, '\PostDoc UCLA\1 Post Doc UCLA\Matlab analysis\MACKtrack_SL\NFkBBaselineAdjustment.mat'],'-mat');
%    load([home_folder(1:slash_idx(end-1)), 'BaselineAdjustment.mat'],'-mat'); % loads locations.mat from home folder
    nfkb = nfkb - NFkBBaselineCorrFact(1:size(nfkb, 2));
end

%Plot baseline subtracted trajectories
if verbose_flag
    figure, imagesc(nfkb,prctile(nfkb(:),[5,99])),colormap(parula), colorbar %plots raw baseline-subttracted trajectories, using 5th and 99th percentile of nfkb as limits
    title('All (baseline-subtracted) NFkB trajectories')
end

%KTR quantification    
if strcmpi(p.Results.IncludeKTR,'on')
    ktr = measure.KTR_ratio1(:,:); %ktr is defined as KTR cytoplasmic/nuclear ratio from ktr module

    %KTR baseline deduction 
    ktr_baseline = nanmean(ktr(:,1:StimulationTimePoint),2); 
    ktr_no_base_ded =  ktr; % ktr activity is defined as baseline - fluorescence measurement
    if strcmpi(p.Results.KTRBaselineDeduction,'on')
        ktr =  ktr - ktr_baseline; % ktr activity is defined as baseline - fluorescence measurement
    end
    if verbose_flag
        figure, imagesc(ktr,prctile(ktr(:),[5,99])),colormap(parula), colorbar %plots raw baseline-subttracted trajectories, using 5th and 99th percentile of ktr ratio as limits
        title('All (baseline-subtracted) KTR trajectories')
    end
    %KTR Baseline shift adjustment based on general mock values
    if strcmpi(p.Results.KTRBaselineAdjustment,'on')
%        home_folder = mfilename('fullpath'); % Load locations (for images and output data)%mfilename returns path of currently running code
%        slash_idx = strfind(home_folder,filesep); %looks for system-specific file separator in home_folder
        OneDrivePath = getenv('OneDrive');
        load([OneDrivePath, '\PostDoc UCLA\1 Post Doc UCLA\Matlab analysis\MACKtrack_SL\KTRBaselineAdjustment.mat'],'-mat');
%       load([home_folder(1:slash_idx(end-1)), 'BaselineAdjustment.mat'],'-mat'); % loads locations.mat from home folder
        ktr = ktr - KTRBaselineCorrFact(1:size(ktr, 2));
    end
end



% Filtering, part 2: eliminate outlier cells (based on mean value)
nfkb_lvl = reshape(nfkb(max(droprows,[],2) == 0,:),[1 numel(nfkb(max(droprows,[],2) == 0,:))]); %sets nfkb level as nfkb measurements of cells (full trajectories) to be kept reshaped to a 1xtotal number of array elements matrix 
droprows =  [droprows, (nanmean(abs(nfkb-nanmean(nfkb_lvl)),2)./nanstd(nfkb_lvl))>=3]; %removes cells with mean levels larger than 3x standard deviation (mean of all values subtracted from each nfkb element, absolute value of that, mean across each trajectory, each element dividided by standard deviation of nfkb level, check if larger or equal than 3, add to droprows as a 1/0 column
droprows =  [droprows, (nanmean(abs(nfkb-nanmean(nfkb_lvl)),2)./nanstd(nfkb_lvl))>=1.7]; %removes cells with mean levels larger than 1.7x standard deviation 

% Filtering, part 2: eliminate outlier cells (based on mean value)
if strcmpi(p.Results.IncludeKTR,'on')
    ktr_lvl = reshape(ktr(max(droprows,[],2) == 0,:),[1 numel(ktr(max(droprows,[],2) == 0,:))]); %sets ktr level as ktr ratio measurements of cells (full trajectories) to be kept reshaped to a 1xtotal number of array elements matrix 
    droprows =  [droprows, (nanmean(abs(ktr-nanmean(ktr_lvl)),2)./nanstd(ktr_lvl))>=3]; %removes cells with mean levels larger than 3x standard deviation (mean of all values subtracted from each ktr element, absolute value of that, mean across each trajectory, each element dividided by standard deviation of ktr level, check if larger or equal than 3, add to droprows as a 1/0 column
    droprows =  [droprows, (nanmean(abs(ktr-nanmean(ktr_lvl)),2)./nanstd(ktr_lvl))>=1.7]; %removes cells with mean levels larger than 1.7x standard deviation(+/- 1.7std includes app 90% of data for normal distr)
end

% Filtering, part 3: nuclear stain intensity 
keep = max(droprows,[],2) == 0; %index of cells to keep are those rows of the droprows vector where no columns show a 1

nuc_lvl = nanmedian(measure.MeanNuc1(keep,1:31),2); %defines nuc_lvl as median nuclear intensity (DNA staining) in first 31 timepoints, for each column/timepoint 
nuc_thresh = nanmedian(nuc_lvl)+2.5*robuststd(nuc_lvl(:),2); %defines the acceptable threshold for nuclear intensity as median of nuclear levels + 2.5x std
info.nuc_lvl = nuc_lvl;
info.nuc_thresh = nuc_thresh;
droprows = [droprows, nanmedian(measure.MeanNuc1(:,1:31),2) > nuc_thresh];%removes cells with median nuclear intensity above nuclear threshold in first 31 timepoints
droprows = [droprows, nanmedian(measure.Area,2) < area_thresh]; %removes cells with median area smaller than the area threshold (to remove small particles)
info.dropped = droprows;

% Show some filter information
if strcmpi(p.Results.IncludeKTR,'off')

    if verbose_flag
        filter_str = {'didn''t exist @ start', 'short-lived cells', 'very dim NFkB',...
            'extreme NFkB val [mean val >3*std]','NFkB outliers [mean>1.7*std]', 'high nuclear stain','low area'};
        disp(['INITIAL: ', num2str(size(droprows,1)),' cells'])
        for i = 1:size(droprows,2)
            if i ==1
                num_dropped = sum(droprows(:,i)==1);
            else
                num_dropped = sum( (max(droprows(:,1:i-1),[],2)==0) & (droprows(:,i)==1));
            end
            disp(['Filter #', num2str(i), ' (',filter_str{i},') - ',num2str(num_dropped), ' cells dropped']) 
        end
        disp(['FINAL: ', num2str(sum(max(droprows,[],2) == 0)),' cells'])
    end
else
    
    if verbose_flag
        filter_str = {'didn''t exist @ start', 'short-lived cells', 'very dim NFkB','very dim and very high KTR Nuc'...
            'extreme NFkB val [mean val >3*std]','NFkB outliers [mean>1.7*std]','extreme KTR val [mean>3*std]', 'KTR outliers [mean val >1.7*std]', 'high nuclear stain','low area'};
        disp(['INITIAL: ', num2str(size(droprows,1)),' cells'])
        for i = 1:size(droprows,2)
            if i ==1
                num_dropped = sum(droprows(:,i)==1);
            else
                num_dropped = sum( (max(droprows(:,1:i-1),[],2)==0) & (droprows(:,i)==1));
            end
            disp(['Filter #', num2str(i), ' (',filter_str{i},') - ',num2str(num_dropped), ' cells dropped']) 
        end
        disp(['FINAL: ', num2str(sum(max(droprows,[],2) == 0)),' cells'])
    end
end

info.keep = max(droprows,[],2) == 0;
nfkb = nfkb(info.keep,:); %nfkb is redefined as only the not-filtered-out cells
nfkb_no_base_ded = nfkb_no_base_ded(info.keep,:);
nfkb_baseline = nfkb_baseline(info.keep, :);

if strcmpi(p.Results.IncludeKTR,'on')
    ktr = ktr(info.keep,:);
    ktr_no_base_ded = ktr_no_base_ded(info.keep,:);
    ktr_baseline = ktr_baseline(info.keep, :);
end
%% Initialize outputs, do final corrections
graph.celldata = info.CellData(info.keep,:); %graph.celldata is set to include celldata from all the non-filtered out cells

graph.var_nfkb = nfkb;
graph.var_nfkb_no_base_ded = nfkb_no_base_ded;
info.nfkb_baseline = nfkb_baseline;
if strcmpi(p.Results.IncludeKTR,'on')
    graph.var_ktr = ktr;
    graph.var_ktr_no_base_ded = ktr_no_base_ded;
    info.ktr_baseline = ktr_baseline;
end

graph.t = ((-StimulationTimePoint+1)/info.parameters.FramesPerHour):(1/info.parameters.FramesPerHour):48; %creates a time axis vector for the graph from 0 to 48 in steps of 1/FramesperHour (12)
graph.t = graph.t(1:min([length(graph.t),size(graph.var_nfkb,2)]));%time axis vector shortened to number of timepoints in data (if shorter)
