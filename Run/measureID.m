function [] = measureID(varargin)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [] = measureID(varargin)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% MEASUREID queues and measures multiple experimental sets from the "Scope Runs" Google Doc 
% Choose sets by ID number. This function is identical to runID, but assumes cells have been
% tracked already. (Alternately, you can also pass a parameters structure, or file location
% as an input arguement)
%
%
% INPUT:
% varargin     ID# of sets to track (1st column of spreadsheet) - single values or vector
%              (optionally, you can specify a single parameters structure or file location)
%
% Example Usage: runById(1,4:16,27) will track, sequentially, 15 experimental sets using
% the parameters specified in the Google Doc.
% 
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Specify save directory and load spreadsheet URL
home_folder = mfilename('fullpath');
slash_idx = strfind(home_folder,filesep);
home_folder = home_folder(1:slash_idx(end-1));
load([home_folder, 'locations.mat'],'-mat')
if ~exist(locations.scope)
    error(['Invalid mount location for images: "',locations.scope,...
        '" not found. Please load, update, and re-save "locations.mat"'])
end



% OPTION 1: pass indicies corresponding to row entries in a spreadsheet.
if isnumeric(varargin{1})
    [~,status] = urlread(locations.spreadsheet);
    if ~status
    error(['Spreadsheet URL load unsuccessful. Please load, update, and re-save "locations.mat"'])
    end
    % Read in content from the "Scope Runs - Tracking Sets" spreadsheet
    data = readScopeRuns(locations.spreadsheet, cell2mat(varargin));
    run_tot = numel(data.save_folder);


    % Display the sets we're running
    for idx = 1:run_tot
        disp(['- ',data.save_folder{idx}])
    end

    % Cycle/measure sets
    for idx = 1:run_tot
        % PARAMETERS
        load([home_folder,'Parameters',filesep,data.parameter_files{idx}])
        parameters.ImagePath = data.image_paths{idx};
        parameters.TimeRange = eval(data.time_ranges{idx});
        parameters.XYRange = eval(data.xy_ranges{idx});
        parameters.SaveDirectory = [data.save_dir{idx},filesep,data.save_folder{idx}];
        p = parameters; eval(data.modify{idx}); parameters = p;  % Overwrite parameters as necessary
        if ~isfield(parameters,'Parallel')
            parameters.Parallel = length(parameters.XYRange)>1;
        end
        % MEASUREMENT
        disp(['Measuring ', parameters.SaveDirectory,'...'])
        try
            MACKmeasure(parameters);      
        catch ME
            disp(['Error in measurement:' , ME.message])
            for err = 1:length(ME.stack)
                disp(['-> ', ME.stack(err).name,', line ', num2str(ME.stack(err).line)])
            end
            error('killing measurement')
        end
    end
    
    
% OPTION2: parameters file (or structure) was passed directly
else
    if ischar(varargin{1})
        load(varargin{1})
    elseif isstruct(varargin{1})
        parameters = varargin{1};
    else
        error(['measureID accepts a parameters structure, file location, or row entries',...
            'of experiments (from scope spreadsheet). Type ''help measureID'' for further detail'])
    end
    % MEASUREMENT
    if ~isfield(parameters,'Parallel')
        parameters.Parallel = length(parameters.XYRange)>1;
    end
    disp(['Measuring ', parameters.SaveDirectory,'...'])
    try
        MACKmeasure(parameters);      
    catch ME
        disp(['Error in measurement:' , ME.message])
        for err = 1:length(ME.stack)
            disp(['-> ', ME.stack(err).name,', line ', num2str(ME.stack(err).line)])
        end
        error('killing measurement')
    end
end