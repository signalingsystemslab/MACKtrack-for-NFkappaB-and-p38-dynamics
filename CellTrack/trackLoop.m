function [] = trackLoop(parameters,xyPos)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% [] = trackLoop(parameters,xyPos)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% TRACKLOOP takes a time-lapse image series and converts into  into segmented, tracked data. 
% Output cellular trajetories are saved as successive label matricies.
%
% Main subfunctions/subscripts
% phaseID.m/dicID.m, nucleusID.m, trackNuclei.m. dicCheck.m, phaseSegment.m/dicSegment.m
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
parameters.debug = 0;

% SETUP: define options, initialize structures for images/masks/label matricies
home_folder = mfilename('fullpath');
slash_idx = strfind(home_folder,filesep);
load([home_folder(1:slash_idx(end-1)), 'locations.mat'],'-mat')
image_jumps = [1 0 0];

images = struct;
tocs = struct;
switch lower(parameters.ImageType)
    case 'dic'
        fnstem = 'dic';
        X = []; 
    case 'phase'
        fnstem = 'phase';
        X = backgroundcalculate(parameters.ImageSize);
    case 'fluorescence'
        fnstem = 'fluorescence';
        X = [];
    case 'none';
        fnstem = 'primary';
        X = [];
end


% Get image bit depth
i = xyPos;
j =  parameters.TimeRange(1);
imfo = imfinfo(namecheck([locations.scope,parameters.ImagePath,eval(parameters.NucleusExpr)]));
bit_depth = imfo.BitDepth;

% Make save directories, save tracking parameters
outputDirectory = namecheck([locations.data,filesep, parameters.SaveDirectory,filesep,'xy',num2str(xyPos),filesep]);
mkdir(outputDirectory)
mkdir([outputDirectory,'NuclearLabels'])    
mkdir([outputDirectory,'CellLabels'])
mkdir([outputDirectory,'SegmentedImages'])

% Convert any parameter flatfield images to functions
if isfield(parameters,'Flatfield')
    parameters.Flatfield = processFlatfields(parameters.Flatfield);
end


% Make default shift (for tracking cells across image jumps)
parameters.ImageOffset = repmat({[0 0]},1,parameters.StackSize);
if sum(isinf(parameters.ImageJumps))>0
    parameters.ImageJumps = parameters.TimeRange;
end
parameters.ImageJumps(parameters.ImageJumps==min(parameters.TimeRange)) = []; % (Error check: can't do a jump w/o a reference)

% Check to make sure time vector is long enough
if length(parameters.TimeRange) < parameters.StackSize
   error('Time vector is too short for specified stack size, aborting tracking.')
end

% Save tracking/memory checking text output
fid = fopen([outputDirectory,'decisions.txt'],'w','n','UTF-8');
fwrite(fid, sprintf(['Tracking/checking decisions for xy pos ',num2str(xyPos),':\n']));
fclose(fid);

% Turn off combine structures warning
warning('off','MATLAB:combstrct')


% Loop all time points
for cycle = 1:(length(parameters.TimeRange)+parameters.StackSize-1)
    tic
    trackstring = '';
    
    % "FUTURE" handling.
    if cycle<=length(parameters.TimeRange)
        i = xyPos;
        j =  parameters.TimeRange(cycle);
        parameters.i = i; parameters.j = j;

        % Load in images
        tic
        nucName1 = eval(parameters.NucleusExpr);
        images.nuc = checkread(namecheck([locations.scope,parameters.ImagePath,nucName1]),bit_depth,1,parameters.debug);
        if ~strcmpi(parameters.ImageType,'none')
            cellName1 = eval(parameters.CellExpr);
            images.cell = checkread(namecheck([locations.scope,parameters.ImagePath,cellName1]),bit_depth,1,parameters.debug);
        else
            images.cell = images.nuc;
        end
        tocs.ImageLoading = toc;

        
        % Calculate image jump, if parameters require it.
        if ismember(parameters.TimeRange(cycle), parameters.ImageJumps)
            j =  parameters.TimeRange(cycle-1);
            if strcmpi(parameters.ImageType,'none')
                prev_name = eval(parameters.NucleusExpr);
            else
                prev_name = eval(parameters.CellExpr);
            end
            prev_img = checkread(namecheck([locations.scope,parameters.ImagePath,prev_name]),bit_depth,1,parameters.debug);
            new_offset = parameters.ImageOffset{end}+calculatejump(prev_img,images.cell);
            disp(['Jump @ frame ',num2str(parameters.TimeRange(cycle)),'. Curr. offset: [',num2str(new_offset),']'])
            image_jumps = cat(1,image_jumps,[parameters.TimeRange(cycle) new_offset]);
            
            
        else
            new_offset = parameters.ImageOffset{end};
        end
        parameters.ImageOffset = [parameters.ImageOffset(2:end),{new_offset}];
            
        
        % CELL MASKING on phase contrast/DIC image
        tic
        maskfn = str2func([fnstem,'ID']);
        if strcmpi(parameters.ImageType,'fluorescence')
            X = []; % Don't use (optional) nuclear image to mask
        end
        data = maskfn(images.cell,parameters,X); % either phaseID or dicID (3 args)
        tocs.CellMasking = toc;

        % NUCLEAR IDENTIFICATION
        tic
        present = nucleusID(images.nuc,parameters,data);
        data = combinestructures(present,data);
        tocs.NucMasking = toc;

        % NUCLEUS/CELL CHECKS (preliminary)
        tic
        present = doubleCheck(data, images, parameters);
        data = combinestructures(present,data);
        tocs.CheckCells = toc;

        % Update stacks/structs with each iteration      
        % After fill loops, empty bottom on update
        if cycle>parameters.StackSize
            future(1) = [];
        end
        % Concatenate new information into 'future' queue
        if cycle==1
            future = data;
        else
            future = cat(1,future,data);
        end
    else % For final frames (i.e. those with incomplete stack), fill in "future" with dummy data
        future(1) = [];
        tmpnames = fieldnames(future(end));
        data = struct;
        for z = 1:length(tmpnames)
            if islogical(future(end).(tmpnames{z}))
                data.(tmpnames{z}) = false(size(future(end).(tmpnames{z})));
            else
                data.(tmpnames{z}) = zeros(size(future(end).(tmpnames{z})));
            end
        end
        future = cat(1,future,data);   
        tocs.ImageLoading = 0; tocs.CellMasking = 0; tocs.NucMasking = 0; tocs.CheckCells = 0; % zero out unused tics
        parameters.ImageOffset = [parameters.ImageOffset(2:end),{[0 0]}];
    end
   
    
   if cycle >= parameters.StackSize
       % Bookkeeping (indicies), initialization for tracking 
        saveCycle = cycle-parameters.StackSize+1; % Value assigned to CellData and tracked label matricies
        j = parameters.TimeRange(saveCycle); % Number of the input image corresponding to the BOTTOM of stack
        % Re-read image corresponding to bottom of the stack (for segmentation and saving)
        if strcmpi(parameters.ImageType,'none')
            images.bottom = checkread(namecheck([locations.scope,parameters.ImagePath,eval(parameters.NucleusExpr)])...
                ,bit_depth,1,parameters.debug);
        else
            images.bottom = checkread(namecheck([locations.scope,parameters.ImagePath,eval(parameters.CellExpr)])...
            ,bit_depth,1,parameters.debug);
        end
                
        % TRACKING: Initialize CellData (blocks and CellData) when queue is full, then track nuclei
        tic
        if cycle == parameters.StackSize
            [CellData, future] = initializeCellData(future,parameters);
        else
            trackstring = [trackstring,'\n- - - Cycle ',num2str(saveCycle),' - - -\n'];
            [tmpstring, CellData, future] =  evalc('trackNuclei(future, CellData, saveCycle, parameters)');
            trackstring = [trackstring,tmpstring];
        end
        tocs.Tracking = toc;    
        
        % SEGMENT CELLS (bottom of "future" queue)
        tic
        segmentfn = str2func([fnstem,'Segment']);
        present = segmentfn(future(1), images.bottom, parameters);
        tocs.Segmentation = toc;
        present.ImageOffset = parameters.ImageOffset{1};
       
        % MEMORY CHECKING ("past" queue)
        tic
        if ~exist('past','var')
            past = combinestructures(future(1),present);
        else
            present = combinestructures(future(1),present);
            past = cat(1,present,past);
            if length(past) >= 2
                [tmpstring, CellData, past] =  evalc('memoryCheck(CellData, past, images.bottom, saveCycle, parameters)');
                trackstring = [trackstring,tmpstring];
                if length(past)>2
                    past(end) = []; % Cap @ 2 frames of memory
                end
            end
        end
        tocs.MemoryChecking = toc;
        
        % Final CellData cleanup: mark cells that touch the edge of image - - - -
        edgeCheck = past(1).cells;
        edgeCells = unique([edgeCheck(1,:),edgeCheck(end,:),edgeCheck(:,1)',edgeCheck(:,end)']);
        edgeCells(edgeCells==0) = [];
        CellData.Edge(edgeCells) = 1;
        
        % SAVING (label mats, segmentated images, decisions.txt)
        tic
        % Save nuclear labels
        NuclearLabel = uint16(past(1).nuclei);
        save([outputDirectory,'NuclearLabels',filesep,'NuclearLabel-',numseq(saveCycle,4),'.mat'], 'NuclearLabel')
        % Save cell labels
        CellLabel = uint16(past(1).cells);
        save([outputDirectory,'CellLabels',filesep,'CellLabel-',numseq(saveCycle,4),'.mat'], 'CellLabel')   
        
        % Save composite 'Segmentation' image
        output_res = [1024 1024];
        if strcmpi(parameters.ImageType,'phase')|| strcmpi(parameters.ImageType,'dic') % BRIGHTFIELD MODALITIES
            saturation_val = [-2 4];
            alpha = 0.30;
        else % FLUORESCENCE MODALITIES - SNR varies between conditions, so guess a display range from an early img
            if ~exist('saturation_val','var')
                tmp1 = images.cell;
                tmp1(tmp1==min(tmp1(:))) = [];
                tmp1(tmp1==max(tmp1(:))) = [];
                tmp1 = modebalance(tmp1,0, bit_depth,'display');               
                % Non-confluent case - set low saturation @ 3xS.D. below bg level
                if parameters.Confluence ~= 1
                    
                    pct = 90:.5:99;
                    hi_val = prctile(tmp1,pct);       
                    saturation_val = [-3 prctile(tmp1,1+findelbow(pct,hi_val))];
                    alpha = 0.4;
                else % Confluent case: unimodal distribution is foreground - use a different lower limit.
                    saturation_val = [-4 prctile(tmp1(:),90)];
                    alpha = 0.55;
                end
            end
        end
        saveFig(images.bottom,CellLabel,NuclearLabel, [],bit_depth,...
            [outputDirectory,'SegmentedImages',filesep,'Segmentation-',numseq(saveCycle,4),'.jpg'],  ...
            alpha, output_res, saturation_val)
        tocs.Saving = toc;
        % Save decisions.txt
        fid = fopen([outputDirectory,'decisions.txt'],'a','n','UTF-8');
        fwrite(fid, sprintf(trackstring));
        fclose(fid);
   end
    
    
    
    % - - - - Display progress/times taken for mask/track/segment - - - -
    name1 = parameters.SaveDirectory;
    if ~isempty(name1) && strcmp(name1(end),filesep)
        name1 = name1(1:end-1);
    end
    seps = strfind(name1,filesep);
    if ~isempty(seps)
        seps = seps(end);
        name1 = name1(seps+1:end);
    end
    str = '\n- - - - - - - - - - - - - - -';
    name1(strfind(name1,'\')) = '/';
    if cycle < parameters.StackSize
        str = sprintf([str, '\n', name1, ' - XY ', num2str(xyPos),', Fill Cycle ', num2str(cycle)]);
    else
        str = sprintf([str, '\n', name1, ' - XY ', num2str(xyPos),', Save Cycle ', num2str(saveCycle)]);
    end
        str = sprintf([str, '\n', 'Nucleus Image: ',nucName1]);
    n = fieldnames(tocs);
    for k = 1:length(n)
        str = sprintf([str '\n', n{k},'- ',num2str(tocs.(n{k})),' sec']);
    end
    fprintf([str, '\n'])

end



% Save CellData and accessory data
save([outputDirectory,'CellData.mat'],'CellData')
save([outputDirectory,'ImageJumps.mat'],'image_jumps')

