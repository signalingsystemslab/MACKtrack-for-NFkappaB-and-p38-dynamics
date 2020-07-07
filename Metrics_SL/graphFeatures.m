function [ID] = graphFeatures(IDs, varargin)

%20200625 graphs features for Violin Plots, %responders, %oscillators for NFkB and KTR
%also provides features with option for filtering based on responder status


%for any number of experiment IDs
p = inputParser;
addRequired(p,'IDs'); %vector containing IDs to be plotted
%parameters to be passed to metric function
expectedFlags = {'on','off'};
valid_conv = @(x) assert(isnumeric(x)&&(x>=0)&&(length(x)==1),...
    'Parameter must be single integer >= 0'); %checks whether parameters below are single integers
addParameter(p,'Verbose','off', @(x) any(validatestring(x,expectedFlags)));%checks whether optional name-value argument matches on or off %checks if x matches expectedFlags
addParameter(p,'MinLifetime',109, @isnumeric); %allows adjustment of minimum lifetime (?)
addParameter(p,'MinSize',90, valid_conv); %allows adjustment of minimum size (?)
addParameter(p,'TrimFrame',157, @isnumeric);
addParameter(p,'StartThreshNFkB',14, valid_conv);%max allowable starting threshhold (before baseline deduction)to filter out cells with pre-activated NFkB
addParameter (p, 'OnThreshNFkB', 3, @isnumeric); %sigma threshold for determining responders
addParameter (p, 'GraphLimitsNFkB',[-0.25 7],@isnumeric);
addParameter(p,'StartThreshKTR',0.9, valid_conv); %max allowable starting threshhold to filter out cells with pre-activated KTR, default is 0.6
addParameter (p, 'OnThreshKTR', 3, @isnumeric); %sigma threshold for determining responders
addParameter(p, 'StimulationTimePoint', 13, @isnumeric);
addParameter(p, 'FramesPerHour', 12, @isnumeric);

%parameter to access metrics to be graphed in violin plots
addParameter(p, 'FeatureListFile', 'C:\Users\stlue\OneDrive\PostDoc UCLA\1 Post Doc UCLA\Matlab analysis\MACKtrack_SL\Metrics_SL\FeatureList.xlsx') %provide file path for Excel table with list of feature to be computed

expectedFilters = {'none','nfkb', 'ktr', 'both', 'respective'};
addParameter(p, 'FilterResponders','none', @(x) any(validatestring(x,expectedFilters)));%filter out non-responders or not

parse(p,IDs, varargin{:})

ViolMetTableNFkB = readtable(p.Results.FeatureListFile, 'Sheet', 'ViolFeatTableNFkB');
viol_met_nfkb = table2cell(ViolMetTableNFkB(:,1)); %list of metrics/features to be plotted
viol_met_index_nfkb = table2cell(ViolMetTableNFkB(:,2)); %index for metrics with multiple columns (eg duration, etc.)
viol_met_units_nfkb = table2cell(ViolMetTableNFkB(:,3));
ViolMetTableKTR= readtable(p.Results.FeatureListFile, 'Sheet', 'ViolFeatTableKTR');
viol_met_ktr = table2cell(ViolMetTableKTR(:,1)); %list of metrics/features to be plotted
viol_met_index_ktr = table2cell(ViolMetTableKTR(:,2)); %index for metrics with multiple columns (eg duration, etc.)
viol_met_units_ktr = table2cell(ViolMetTableKTR(:,3));

%viol_met_nfkb = {'off_times_nfkb','max_amplitude_nfkb','max_integral_nfkb','pk1_amp_nfkb', 'pk2_amp_nfkb','peakfreq_nfkb','max_derivative_nfkb', 'min_derivative_nfkb', 'pk1_time_nfkb', 'pk2_time_nfkb'};
%viol_met_ktr = {'off_times_ktr','max_amplitude_ktr','max_integral_ktr','pk1_amp_ktr', 'pk2_amp_ktr','peakfreq_ktr','max_derivative_ktr', 'min_derivative_ktr', 'pk1_time_ktr', 'pk2_time_ktr'};

n = numel(IDs);
ID(n).metrics = [];
ID(n).graph = [];
ID(n).info = [];
ID(n).features = [];

figure
tiledlayout(4,round(numel(viol_met_nfkb)/2)) %looks best when using even number of metrics/features

% Metrics for NFkB
%run metrics function of desired exp ID
for i= 1:n
    [ID(i).metrics,~,ID(i).graph,ID(i).info,~] = nfkb_ktr_ratio_metrics(IDs(i), 'MinLifetime',p.Results.MinLifetime,...
                            'OnThreshNFkB',p.Results.OnThreshNFkB,'OnThreshKTR',p.Results.OnThreshKTR,...
                            'MinSize', p.Results.MinSize,'StartThreshNFkB', p.Results.StartThreshNFkB,'StartThreshKTR', p.Results.StartThreshKTR, 'Verbose', ... 
                            p.Results.Verbose, 'TrimFrame', p.Results.TrimFrame, 'StimulationTimePoint', p.Results.StimulationTimePoint);
    ID(i).features = computeFeatures(IDs(i), 'metrics', ID(i).metrics, 'FeatureListTable', [ViolMetTableNFkB;ViolMetTableKTR],... 
                                'MinLifetime',p.Results.MinLifetime, 'OnThreshNFkB',p.Results.OnThreshNFkB,'OnThreshKTR',p.Results.OnThreshKTR,...
                                'MinSize', p.Results.MinSize,'StartThreshNFkB', p.Results.StartThreshNFkB,'StartThreshKTR', p.Results.StartThreshKTR, 'Verbose', ... 
                                p.Results.Verbose, 'TrimFrame', p.Results.TrimFrame, ...
                                'StimulationTimePoint', p.Results.StimulationTimePoint, 'FramesPerHour', p.Results.FramesPerHour);

end

switch p.Results.FilterResponders 
    case 'none'
       for i = 1:n
        for k = 1:numel(viol_met_nfkb)
            if i==1 
            violin.(viol_met_nfkb{k}) = {ID(i).features.(viol_met_nfkb{k})(:, viol_met_index_nfkb{k})};
            else
            violin.(viol_met_nfkb{k}) = [violin.(viol_met_nfkb{k}), ID(i).features.(viol_met_nfkb{k})(:, viol_met_index_nfkb{k})];
            end
        end
       end
    case {'nfkb', 'respective'}
       for i = 1:n
        for k = 1:numel(viol_met_nfkb)
            if i==1 
            violin.(viol_met_nfkb{k}) = {ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_nfkb == 1, viol_met_index_nfkb{k})};
            else
            violin.(viol_met_nfkb{k}) = [violin.(viol_met_nfkb{k}), ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_nfkb == 1,viol_met_index_nfkb{k})];
            end
        end
       end
    case 'ktr'
       for i = 1:n
        for k = 1:numel(viol_met_nfkb)
            if i==1 
            violin.(viol_met_nfkb{k}) = {ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_ktr == 1, viol_met_index_nfkb{k})};
            else
            violin.(viol_met_nfkb{k}) = [violin.(viol_met_nfkb{k}), ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_ktr == 1, viol_met_index_nfkb{k})];
            end
        end
       end
    case 'both'
       for i = 1:n
        for k = 1:numel(viol_met_nfkb)
            if i==1 
            violin.(viol_met_nfkb{k}) = {ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_nfkb == 1 & ID(i).metrics.responder_index_ktr == 1, viol_met_index_nfkb{k})};
            else
            violin.(viol_met_nfkb{k}) = [violin.(viol_met_nfkb{k}), ID(i).features.(viol_met_nfkb{k})(ID(i).metrics.responder_index_nfkb == 1 & ID(i).metrics.responder_index_ktr == 1, viol_met_index_nfkb{k})];
            end
        end
       end   
end

violin_spacing = 1:n;
for k = 1:numel(viol_met_nfkb)
 %   violin_mack(violin.(viol_met_nfkb{k}), violin_spacing, 'Area', 0.05, 'YLim', [-5 15])
    axes.ax(k) = nexttile;
    violin_mack(violin.(viol_met_nfkb{k}),violin_spacing,'Axes', axes.ax(k), 'Area', 0.04,'XSpace', 0.1, 'BinScale', 1,'Smoothing', 'on', 'Connect', 'on', 'MarkerSize', 7, 'ShowBins', 'off');
    title([viol_met_nfkb{k},' ',num2str(viol_met_index_nfkb{k})], 'Interpreter', 'none')
    ylabel(viol_met_units_nfkb{k})
end

%% KTR metrics

%figure
%tiledlayout(2,round(numel(viol_met)/2))

switch p.Results.FilterResponders 
    case 'none'
       for i = 1:n
        for k = 1:numel(viol_met_ktr)
            if i==1 
            violin.(viol_met_ktr{k}) = {ID(i).features.(viol_met_ktr{k})(:, viol_met_index_ktr{k})};
            else
            violin.(viol_met_ktr{k}) = [violin.(viol_met_ktr{k}), ID(i).features.(viol_met_ktr{k})(:, viol_met_index_ktr{k})];
            end
        end
       end
    case 'nfkb'
       for i = 1:n
        for k = 1:numel(viol_met_ktr)
            if i==1 
            violin.(viol_met_ktr{k}) = {ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_nfkb == 1,viol_met_index_ktr{k})};
            else
            violin.(viol_met_ktr{k}) = [violin.(viol_met_ktr{k}), ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_nfkb == 1,viol_met_index_ktr{k})];
            end
        end
       end
    case {'ktr', 'respective'}
       for i = 1:n
        for k = 1:numel(viol_met_ktr)
            if i==1 
            violin.(viol_met_ktr{k}) = {ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_ktr == 1, viol_met_index_ktr{k})};
            else
            violin.(viol_met_ktr{k}) = [violin.(viol_met_ktr{k}), ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_ktr == 1,viol_met_index_ktr{k})];
            end
        end
       end
    case 'both'
       for i = 1:n
        for k = 1:numel(viol_met_ktr)
            if i==1 
            violin.(viol_met_ktr{k}) = {ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_nfkb == 1 & ID(i).metrics.responder_index_ktr == 1,viol_met_index_ktr{k} )};
            else
            violin.(viol_met_ktr{k}) = [violin.(viol_met_ktr{k}), ID(i).features.(viol_met_ktr{k})(ID(i).metrics.responder_index_nfkb == 1 & ID(i).metrics.responder_index_ktr == 1,viol_met_index_ktr{k})];
            end
        end
       end    
end    

violin_spacing = 1:n;
for k = 1:numel(viol_met_ktr)
 %   violin_mack(violin.(viol_met_ktr{k}), violin_spacing, 'Area', 0.05, 'YLim', [-5 15])
    axes.ax(k) = nexttile;
    violin_mack(violin.(viol_met_ktr{k}),violin_spacing,'Axes', axes.ax(k), 'Area', 0.04,'XSpace', 0.1, 'BinScale', 1,'Smoothing', 'on', 'Connect', 'on', 'MarkerSize', 7, 'ShowBins', 'off');
    title([viol_met_ktr{k},' ',num2str(viol_met_index_ktr{k})], 'Interpreter', 'none')
    ylabel(viol_met_units_ktr{k})
end
