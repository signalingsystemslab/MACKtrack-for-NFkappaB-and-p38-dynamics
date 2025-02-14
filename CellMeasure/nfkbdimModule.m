function [CellMeasurements, ModuleDataOut] = nfkbdimModule(CellMeasurements,parameters, labels, AuxImages, ModuleData)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% NFKBDIMMODULE  measure nuclear fraction in auxiliary (fluorescent) image.
%
% CellMeasurements    structure with fields corresponding to cell measurements
%
% parameters          experiment data (total cells, total images, output directory)
% labels              Cell,Nuclear label matricies (labels.Cell and labels.Nucleus)
% AuxImages           images to measure
% ModuleData          extra information (current ModuleData.iter, etc.) used in measurement 
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

% IMAGE CORRECTION % 2 possibilities for Background correction
% Background correct, method 1: use flatfield image. 
if length(AuxImages)>1 % If more than one image in the fluorescence channel?? If more than one fluorescence channel?  
    if isequal(size(AuxImages{1}),size(parameters.Flatfield{1})) %check whether size of AuxImage and Flatfield image provided match %I think we provide a flatfield image in the Macktrack GUI
        AuxImages{1} = double(AuxImages{1}) - double(parameters.Flatfield{end}); %create double-precision arrays, substract last flatfield image from first AuxImage???
        nfkb = flatfieldcorrect(AuxImages{1},double(parameters.Flatfield{1}));%nfkb is defined as flatfield corrected AuxImage pixels 
    else
        error(['Size mismatch between provided flatfield (#', num2str(img), ' and AuxImage'])
    end
else
% Flatfield correct, method 2: apply quadratic model to image
    if ~isfield(ModuleData,'X') %do not fully understand when this is used?
        ModuleData.X = backgroundcalculate(size(AuxImages{1}));
    end
    warning off MATLAB:nearlySingularMatrix
    pStar = (ModuleData.X'*ModuleData.X)\(ModuleData.X')*double(AuxImages{1}(:));
    warning on MATLAB:nearlySingularMatrix
    % Apply background correction
    nfkb = reshape((double(AuxImages{1}(:) - ModuleData.X*pStar)),size(AuxImages{1}));
    nfkb = nfkb-min(nfkb(:)); % Set minimum to zero
end

% Background correct (use unimodal model)
if ~isfield(ModuleData,'distr') 
    [~, ModuleData.distr] = modebalance(nfkb,1,ModuleData.BitDepth,'measure');
else
    nfkb = modebalance(nfkb,1,ModuleData.BitDepth,'correct',ModuleData.distr);
end

% MEASUREMENT
% On first call, initialize all new CellMeasurements fields 
if ~isfield(CellMeasurements,'NFkBdim_Nuclear')
    % Intensity-based measurement initialization
    CellMeasurements.NFkBdim_Nuclear = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdim_Nuclear_erode = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdim_Cyto_full = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdim_Cyto_annu = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdim_Ratio = nan(parameters.TotalCells,parameters.TotalImages);
    
end

% Count cells for each frame, initialize bins
cells = unique(labels.Nucleus);
cells(cells==0) = [];

[~, distr2] = modebalance(nfkb(labels.Cell==0),1,ModuleData.BitDepth,'measure'); %determines distribution of areas that are not cells?


tmp_mask = imdilate(labels.Nucleus>0,diskstrel(parameters.MinNucleusRadius*1.25));
labels.Cell_annu = labels.Cell;
labels.Cell_annu = IdentifySecPropagateSubfunction(double(labels.Nucleus),zeros(size(labels.Nucleus)),tmp_mask,100);
labels.Cell_annu = uint16(labels.Cell_annu);

% Cycle through each image and assign measurements
for i = 1:length(cells)
    nucleus = labels.Nucleus==cells(i);
    nucleus_erode = imerode(labels.Nucleus==cells(i),diskstrel(1)); %creates eroded version of nuclear measurement, used in some KO experiments diskstrel creates round object of radius 1, 

    cytoplasm_full = (labels.Cell==cells(i)) &~nucleus;
    
    cytoplasm_annu = (labels.Cell_annu==cells(i)) &~nucleus;
    
    a = median(nfkb(nucleus));
    a_erode = median(nfkb(nucleus_erode));

    b = (mean(nfkb(cytoplasm_full))-distr2(1)); %this includes a background correction for the cytoplasmic value?
    if b<0
        b = 0;
    end
    b = b*numel(nfkb(cytoplasm_full));
    
    %202003 test to include annulus-based cytoplasm and ratio
    c = median(nfkb(cytoplasm_annu));
    
    %disp(['nuc: ', num2str(a),'. cyto: ',num2str(b)])
    % Assign measurements
    CellMeasurements.NFkBdim_Nuclear(cells(i),ModuleData.iter) = a;
    CellMeasurements.NFkBdim_Nuclear_erode(cells(i),ModuleData.iter) = a_erode;
    CellMeasurements.NFkBdim_Cyto_full(cells(i),ModuleData.iter) = b;
    CellMeasurements.NFkBdim_Cyto_annu(cells(i),ModuleData.iter) = c;
    CellMeasurements.NFkBdim_Ratio(cells(i),ModuleData.iter) = a/c;
    
end

ModuleDataOut = ModuleData;


%% Intact old version (before trying to use annulus for cytoplasm)
%{
% IMAGE CORRECTION % 2 possibilities for Background correction
% Background correct, method 1: use flatfield image. 
if length(AuxImages)>1 % If more than one image in the fluorescence channel?? If more than one fluorescence channel?  
    if isequal(size(AuxImages{1}),size(parameters.Flatfield{1})) %check whether size of AuxImage and Flatfield image provided match %I think we provide a flatfield image in the Macktrack GUI
        AuxImages{1} = double(AuxImages{1}) - double(parameters.Flatfield{end}); %create double-precision arrays, substract last flatfield image from first AuxImage???
        nfkb = flatfieldcorrect(AuxImages{1},double(parameters.Flatfield{1}));%nfkb is defined as flatfield corrected AuxImage pixels 
    else
        error(['Size mismatch between provided flatfield (#', num2str(img), ' and AuxImage'])
    end
else
% Flatfield correct, method 2: apply quadratic model to image
    if ~isfield(ModuleData,'X') %do not fully understand when this is used?
        ModuleData.X = backgroundcalculate(size(AuxImages{1}));
    end
    warning off MATLAB:nearlySingularMatrix
    pStar = (ModuleData.X'*ModuleData.X)\(ModuleData.X')*double(AuxImages{1}(:));
    warning on MATLAB:nearlySingularMatrix
    % Apply background correction
    nfkb = reshape((double(AuxImages{1}(:) - ModuleData.X*pStar)),size(AuxImages{1}));
    nfkb = nfkb-min(nfkb(:)); % Set minimum to zero
end

% Background correct (use unimodal model)
if ~isfield(ModuleData,'distr') 
    [~, ModuleData.distr] = modebalance(nfkb,1,ModuleData.BitDepth,'measure');
else
    nfkb = modebalance(nfkb,1,ModuleData.BitDepth,'correct',ModuleData.distr);
end

% MEASUREMENT
% On first call, initialize all new CellMeasurements fields 
if ~isfield(CellMeasurements,'NFkBdimNuclear')
    % Intensity-based measurement initialization
    CellMeasurements.NFkBdimNuclear = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdimNuclear_erode = nan(parameters.TotalCells,parameters.TotalImages);
    CellMeasurements.NFkBdimCytoplasm = nan(parameters.TotalCells,parameters.TotalImages);
end

% Count cells for each frame, initialize bins
cells = unique(labels.Nucleus);
cells(cells==0) = [];

[~, distr2] = modebalance(nfkb(labels.Cell==0),1,ModuleData.BitDepth,'measure'); %determines distribution of areas that are not cells?

% Cycle through each image and assign measurements
for i = 1:length(cells)
    nucleus = labels.Nucleus==cells(i);
    nucleus_erode = imerode(labels.Nucleus==cells(i),diskstrel(1)); %creates eroded version of nuclear measurement, used in some KO experiments diskstrel creates round object of radius 1, 

    cytoplasm = (labels.Cell==cells(i)) &~nucleus;
    a = median(nfkb(nucleus));
    a_erode = median(nfkb(nucleus_erode));

    b = (mean(nfkb(cytoplasm))-distr2(1)); %this includes a background correction for the cytoplasmic value?
    if b<0
        b = 0;
    end
    b = b*numel(nfkb(cytoplasm));
    
    %202003 test to include annulus-based cytoplasm and ratio
    c
    
    %disp(['nuc: ', num2str(a),'. cyto: ',num2str(b)])
    % Assign measurements
    CellMeasurements.NFkBdimNuclear(cells(i),ModuleData.iter) = a;
    CellMeasurements.NFkBdimNuclear_erode(cells(i),ModuleData.iter) = a_erode;
    CellMeasurements.NFkBdimCytoplasm(cells(i),ModuleData.iter) = b;
end

ModuleDataOut = ModuleData;
%}
