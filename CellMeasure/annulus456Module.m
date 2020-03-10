function [CellMeasurements, ModuleData] = annulus456Module(CellMeasurements,parameters, labels, AuxImages, ModuleData)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% ANNULUS456MODULE measures cellular intensity (nuclear, cell, and cytoplasmic) in specified AuxImages channels
% (Allows extra-channel measurements, e.g. MeanCell4, MeanCell5, and MeanCell6) -> normalization will use Flatfield4
% Flatfield5, and Flatfield6, accordingly. Boundaries will ALWAYS be annulus boundaries.
%
% CellMeasurements    structure with fields corresponding to cell measurements
%
% parameters          experiment data (total cells, total images, output directory)
% labels              Cell,Nuclear label matricies (labels.Cell and labels.Nucleus)
% AuxImages           images to measure
% ModuleData          extra information (current iteration, etc.) used in measurement 
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

% If cells were not segmented; do annulus to estimate cytoplasmic area.
tmp_mask = imdilate(labels.Nucleus>0,diskstrel(parameters.MinNucleusRadius*1.5)); % (Expand by 1.5 radii)
labels.Cell = IdentifySecPropagateSubfunction(double(labels.Nucleus),zeros(size(labels.Nucleus)),tmp_mask,100);


% Get indicies and bwconncomp structures for measurement
iteration  = ModuleData.iter;

% Make conncomp structures for nucleus, cell, and cytoplasm
nuc_cc = label2cc(labels.Nucleus,0);
cell_cc = label2cc(labels.Cell,0);
cyto_cc = cell_cc;
for i = 1:cyto_cc.NumObjects
    if ~isempty(cyto_cc.PixelIdxList{i})
        cyto_cc.PixelIdxList{i}(ismember(cyto_cc.PixelIdxList{i},nuc_cc.PixelIdxList{i})) = [];
    end
end


% Main cycle: correct image, initialize data (if not present), make measurments
for img = 1:length(AuxImages)
    if ~isempty(AuxImages{img})
        % 1) Background correct image (try to do flatfield, if available)
        if (length(parameters.Flatfield)>=(img+3)) && isequal(size(AuxImages{img}),size(parameters.Flatfield{img+3}))
            img0 = flatfieldcorrect(AuxImages{img}-double(parameters.Flatfield{end}),double(parameters.Flatfield{img+3}));
            img0 = img0-prctile(img0(:),2); % Background subtract
        else
            if ~isfield(ModuleData,'distr')
                [img0, ModuleData.distr] = modebalance(AuxImages{img},2,ModuleData.BitDepth,'measure'); 
            else
                img0 = modebalance(AuxImages{img},2,ModuleData.BitDepth,'correct',ModuleData.distr);
            end
        end


          % - - - - CYTOPLASMIC/WHOLE-CELL measurements - - - -
        % A) Initialize fields
        if ~isfield(CellMeasurements,(['MeanAnnulus_cyto',num2str(img+3)]))
            CellMeasurements.(['MeanAnnulus_cyto',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);
            CellMeasurements.(['MedianAnnulus_cyto',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);
            CellMeasurements.(['IntegratedAnnulus_cyto',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);

            CellMeasurements.(['MeanAnnulus_cell',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);
            CellMeasurements.(['MedianAnnulus_cell',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);
            CellMeasurements.(['IntegratedAnnulus_cell',num2str(img+3)]) =  nan(parameters.TotalCells,parameters.TotalImages);
        end

        % B) Assign measurements
        for n = 1:cyto_cc.NumObjects
            CellMeasurements.(['MeanAnnulus_cyto',num2str(img+3)])(n,iteration) = nanmean(img0(cyto_cc.PixelIdxList{n}));
            CellMeasurements.(['MedianAnnulus_cyto',num2str(img+3)])(n,iteration) = nanmedian(img0(cyto_cc.PixelIdxList{n}));
            CellMeasurements.(['IntegratedAnnulus_cyto',num2str(img+3)])(n,iteration) = nansum(img0(cyto_cc.PixelIdxList{n}));

            CellMeasurements.(['MeanAnnulus_cell',num2str(img+3)])(n,iteration) = nanmean(img0(cell_cc.PixelIdxList{n}));
            CellMeasurements.(['MedianAnnulus_cell',num2str(img+3)])(n,iteration) = nanmedian(img0(cell_cc.PixelIdxList{n}));
            CellMeasurements.(['IntegratedAnnulus_cell',num2str(img+3)])(n,iteration) = nansum(img0(cell_cc.PixelIdxList{n}));
        end
    end
end



