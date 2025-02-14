function [measure, info, AllMeasurements] = loadID(id, verbose)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [measure, info, AllMeasurements] = loadID(id, options)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% LOADID pulls results from an experimental set using a "Scope Runs" Google Doc -
% choose a set by its ID number
%
% INPUTS
% id          ID# of sets get data from (or AllMeasurements.mat file location, or AllMeasurements object)
%
% OUTPUTS:
% measure          full measurement information struct
% info             general information about experiment and tracking
% AllMeasurements  originally-saved output file, augmented w/ measurement-specific information
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if nargin<2 %if function has more than two input arguments, set verbose to 1
    verbose=1;
end

tic %starts stopwatch to measure how long it takes to load results
home_folder = mfilename('fullpath'); % Load locations (for images and output data)%mfilename returns path of currently running code
slash_idx = strfind(home_folder,filesep); %looks for system-specific file separator in home_folder
load([home_folder(1:slash_idx(end-2)), 'locations.mat'],'-mat') % loads locations.mat from home folder%??, whether or not it's a .mat file %? I do not understand how this works...

    % Find/load AllMeasurements.mat - a full file path can be specfied, or an
    % ID corresponding to an entry on the ScopeRuns spreadsheet.
if ischar(id) || isnumeric(id) % Load file if a location or row index of a spreadsheet entry 
    if ~exist(num2str(id), 'file') && isnumeric(id)
        data = readScopeRuns(locations.spreadsheet, id);
        info.name = [data.save_folder{1}];
        load([locations.data,filesep,data.save_dir{1},filesep,info.name,filesep,'AllMeasurements.mat'])
        info.savename = [locations.data,filesep,data.save_dir{1},filesep,info.name,filesep,'AllMeasurements.mat'];
        %20201208 addition SL
        info.dose = data.dose;
        
    elseif exist(num2str(id), 'file') %loads file from specified full file path
        id = namecheck(id);
        load(id)
        info.savename = id;
    else
        error(['Specified file/index (''id'') is invalid'])
    end
elseif isstruct(id)
    AllMeasurements = id;
    info.savename = [locations.data,AllMeasurements.parameters.SaveDirectory,filesep,'AllMeasurements.mat'];
else
    error(['loadID accepts an "AllMeasurements" structure, or a file location/spreadsheet row index.'])
end

info.locations = locations;


% Parse AllMeasurements
info.CellData = AllMeasurements.CellData;
info.fields = fieldnames(AllMeasurements);
info.ImageDirectory = [locations.scope, AllMeasurements.parameters.ImagePath];
measure = struct;
for i = 1:length(info.fields)
    if ~strcmpi(info.fields{i},'parameters') && ~strcmpi(info.fields{i},'CellData')
        measure.(info.fields{i}) = AllMeasurements.(info.fields{i}); 
    end
end
info.fields = fieldnames(measure);

% Add measurement-specific information and add to AllParameters:
% - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% - for see_nfkb calculate base image distributions and threshold for positive NFkB expression
% - for see_nfkb_native, calculate (adjusted) nfkb image background levels
% - - - - - - - - - - - - - - - - - - - - - - - - - - - -
%
% Read in 1st image from each XY position, calculate background mean/std (resave AllParameters)
%12/06/19 temp insertion -- maybe keep?
AllMeasurements.parameters.ImagePath = char(data.image_paths);
p = AllMeasurements.parameters;
try
    if isfield(AllMeasurements,'NFkBNuclear')
        if ~isfield(p, 'nfkb_thresh')
            disp('Measuring and saving initial image distributions')
            nfkb_thresh = zeros(1,length(p.XYRange));
            p.img_distr = zeros(2,length(p.XYRange));
            for ind = 1:length(p.XYRange)
                i = p.XYRange(ind);
                j = min(p.TimeRange);
                expr = p.nfkbModule.ImageExpr;
                if ~exist('bit_depth','var')
                    if isfield(p,'BitDepth')
                        bit_depth = p.BitDepth;
                    else
                        imfo = imfinfo([locations.scope, p.ImagePath, eval(expr)]);
                        bit_depth = imfo.BitDepth;
                    end
                end
                img = checkread([locations.scope, p.ImagePath, eval(expr)],bit_depth,1,1);
                nfkb_thresh(ind) = quickthresh(img,false(size(img)),'log');
                [~,p.img_distr(:,ind)] = modebalance(img,2,bit_depth,'measure');
            end
            p.nfkb_thresh = mean(nfkb_thresh);
            AllMeasurements.parameters = p;
            save(info.savename,'AllMeasurements')
        end
    % 191114 addition    
    end
    
    % Load NFkB measurement (unimodal background) for endogenous NFkB images
    %test 191114
    %elseif isfield(AllMeasurements, 'NFkBdimNuclear') %parameterize this to add ktr
    if isfield(AllMeasurements, 'NFkBdim_Nuclear') %parameterize this to add ktr
       % 12/06/19 temp remove this if statement to re-save info on google sheet to parameters file
        if ~isfield(p, 'adj_distr_NFkBdim')
            disp('Measuring and saving initial (flatfield-corrected) image distributions')
            p.adj_distr_NFkBdim = zeros(2,length(p.XYRange));%creates a matrix with two rows and as many columns as the number of image positions
            for ind = 1:length(p.XYRange)
                % NFkB image distribution
                i = p.XYRange(ind);
                j = min(p.TimeRange);
                expr = p.nfkbdimModule.ImageExpr; %correction (?) 06-21-19, in Ade's version this is also nfkbdimModule
                % expr = p.nfkbModule.ImageExpr; %expr set to code for fluorescence channel for NFkb (e.g.['s',numseq(i,2),'t',numseq(j,3),'c2_ORG.tif'] )
                %determined bit depth either from input variable, from field in parameters, or from image info
               %parameterize this to add ktr
                if ~exist('bit_depth','var')
                    if isfield(p,'BitDepth')
                        bit_depth = p.BitDepth;
                    else
                        imfo = imfinfo([locations.scope, p.ImagePath, eval(expr)]);
                        bit_depth = imfo.BitDepth;
                    end
                end
                img = checkread([locations.scope, p.ImagePath, eval(expr)],bit_depth,1,1); %reads image
            
                if ind==1
                    X = backgroundcalculate(size(img)); %the first time the code is run, creates correction matrix for flatfield correction
                end
                
                warning off MATLAB:nearlySingularMatrix
                pStar = (X'*X)\(X')*double(img(:)); %double is to turn img into double-precision array (the standard array type)
                warning on MATLAB:nearlySingularMatrix
                % Apply background correction
                img = reshape((double(img(:) - X*pStar)),size(img)); %img set to reshaped double-precision array (consisting of img minus the correction matrix multiplied by the factor created above ???)
                img = img-min(img(:)); % Set minimum to zero
                [~,p.adj_distr_NFkBdim(:,ind)] = modebalance(img,1,bit_depth,'measure'); %flatfield corrected image is given to modebalance function to determine adj_distr parameter
                %modebalance normalizes background distribution, provides
                %mu and sigma backgroudn correction factors (row 1 and 2 of adj_distr), but does not change the image
                %?Is img (flatfield adjusted image ?) actually an output?
            end
                AllMeasurements.parameters = p;
                save(info.savename,'AllMeasurements')
        end
    end
    
    %191114 add in adj_distr_ktr
    if isfield(AllMeasurements, 'KTR_nuc1') 
        % 12/06/19 temp remove this if statement to re-save info on google sheet to parameters file
        if ~isfield(p, 'adj_distr_ktr')
            disp('Measuring and saving initial (flatfield-corrected) image distributions')
            p.adj_distr_ktr = zeros(2,length(p.XYRange));%creates a matrix with two rows and as many columns as the number of image positions
            for ind = 1:length(p.XYRange)
                % KTR image distribution
                i = p.XYRange(ind);
                j = min(p.TimeRange);
                expr = p.ktrModule.ImageExpr; 
                %determined bit depth either from input variable, from field in parameters, or from image info
                if ~exist('bit_depth','var')
                    if isfield(p,'BitDepth')
                        bit_depth = p.BitDepth;
                    else
                        imfo = imfinfo([locations.scope, p.ImagePath, eval(expr)]);
                        bit_depth = imfo.BitDepth;
                    end
                end
                img = checkread([locations.scope, p.ImagePath, eval(expr)],bit_depth,1,1); %reads image
            
                if ind==1
                    X = backgroundcalculate(size(img)); %the first time the code is run, creates correction matrix for flatfield correction
                end
                
                warning off MATLAB:nearlySingularMatrix
                pStar = (X'*X)\(X')*double(img(:)); %double is to turn img into double-precision array (the standard array type)
                warning on MATLAB:nearlySingularMatrix
                % Apply background correction
                img = reshape((double(img(:) - X*pStar)),size(img)); %img set to reshaped double-precision array (consisting of img minus the correction matrix multiplied by the factor created above ???)
                img = img-min(img(:)); % Set minimum to zero
                [~,p.adj_distr_ktr(:,ind)] = modebalance(img,1,bit_depth,'measure'); %flatfield corrected image is given to modebalance function to determine adj_distr parameter
                %modebalance normalizes background distribution, provides
                %mu and sigma backgroudn correction factors (row 1 and 2 of adj_distr), but does not change the image
                %?Is img (flatfield adjusted image ?) actually an output?
            end
                AllMeasurements.parameters = p;
                save(info.savename,'AllMeasurements')
        end
    end
    
catch me
    disp(me)
    warning('Couldn''t find original images to measure background distributions - these may be required for some visualization functions.');
end


info.parameters = p;

toc1 = toc;
if verbose
    disp(['Loaded "', info.savename, '" in ', num2str(round(toc1*100)/100),' sec']) 
end