function [colors] = setcolors(graph_flag)
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% COLORS defines a selected palatte for use in graphing
%
% graph_flag    (optional) if true, show colors on heatmap
%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

%Stefanie's colors
colors.dark_blue = [0,0,139]/255;
colors.sky_blue =[135,206,250]/255;
colors.turquoise = [64,224,208]/255;
colors.orange2 = [255,165,0]/255;
colors.light_red =[240,128,128]/255;
colors.dark_red = [178,34,34]/255;

%Stefanie's colors as scheme, darker
colors.dosesDarker{1} = [0,0,139].*0.65/255;
colors.dosesDarker{2}=[135,206,250].*0.65/255;
colors.dosesDarker{3} = [64,224,208].*0.65/255;
colors.dosesDarker{4}= [255,165,0].*0.65/255;
colors.dosesDarker{5} =[240,128,128].*0.65/255;
colors.dosesDarker{6} = [178,34,34].*0.65/255;
colors.dosesDarker{7} =[190,50,50].*0.65/255;
colors.dosesDarker{8} = [220,70,70].*0.65/255;

%Stefanie's colors as scheme
colors.doses{1} = [0,0,139]/255;
colors.doses{2}=[135,206,250]/255;
colors.doses{3} = [64,224,208]/255;
colors.doses{4}= [255,165,0]/255;
colors.doses{5} =[240,128,128]/255;
colors.doses{6} = [178,34,34]/255;
colors.doses{7} =[190,50,50]/255;
colors.doses{8} = [220,70,70]/255;



% W-qbio theme - used darker variants of these for info theory (Selimkhanov, Science 2014)
colors.blue = [62 107 133]/255;
colors.green = [0 195 169]/255;
colors.light_blue = [29 155 184]/255;

% TRAIL color schema
colors.orange = [248 152 29]/255;
colors.lavender = [168 180 204]/255;
colors.navy = [30 50 72]/255;

% Miscellaneous colors
colors.red = [231 76 60]/255;
colors.grays = {[40 40 42]/255,...
    [74 76 79]/255,...
   [113 115 118]/255,...
   [160 165 170]/255}; 

% TLR4 model colors (Science Signaling 2015)
colors.trif = [46 122 145]/255; % blue
colors.both = [120 46 103]/255; % purple
colors.myd = [186 80 73]/255; % red
colors.irf = [48 145 50]/255;

% NFkB stimulus specificity colors
colors.tnf = [118 180 203]/255;
colors.tnf_light = [173 214 228]/255;
colors.lps = [223 79 66]/255;
colors.cpg = [136 180 69]/255;
colors.pam = [230 130 57]/255;
colors.off = [217 210 200]/255;
colors.pic = [101 76 125]/255;
colors.bglu = [243 193 24]/255;
colors.bg_gray = [175 176 179
                  212 213 216
                  232 233 239
                  255 255 255]/255;

%TNFKO project colors
colors.WT = [93,147,191]/255;
colors.WT_light = [159,191,217]/255;
colors.TNFKO = [233,72,73]/255;
colors.TNFKO_light = [241,135,135]/255;
colors.TNFKOP100KO = [119 172 48]/255;
colors.TNFKOP100KO_light = [161 211 95]/255;
colors.CoCulture = [118,83,189]/255;
colors.CoCulture_light = [177,156,217]/255;

% p38 project colors
colors.mVen = [0.9290, 0.6940, 0.1250];
colors.mVenKTR = [119 172 48]/255;
colors.p38 = [68 114 196]/255;
colors.gray = [130 130 130]/255;
colors.NFkBscram = [ 76 188 185]/255;
colors.p38scram = [  189 169 71]/255;
              
% "4th of July" theme - 2 bright, 2 dark.
colors.theme1{1} = colors.red;
colors.theme1{2} = [52 152 219]/255;
colors.theme1{3} = [61 89 117]/255;
colors.theme1{4} = colors.grays{1};


% 'TRAIL' theme - purple to orange
colors.trail{1} = [30 50 72]/255;
colors.trail{2} = [168 180 204]/255;
colors.trail{3} = [255 255 255]/255;
colors.trail{4} = [90 90 91]/255;
colors.trail{5} = [248 152 29]/255;

% Peacock theme
colors.peacock{1} = [140 178 2]/255;
colors.peacock{2} = [0 140 116]/255;
colors.peacock{3} = [0 76 102]/255;
colors.peacock{4} = [51 43 64]/255;

% Phase-switch colors
colors.phase{1} = [91 144 219]/255;
colors.phase{2} = [231 105 80]/255;
colors.phase{3} = [141 87 176]/255;
colors.phase{4} = [21 138 88]/255;
colors.phase{5} = [174 176 178]/255;



if nargin>0
    if graph_flag
        names = fieldnames(colors);
        all_colors = [];
        tick_names = {};
        for i  = 1:length(names)
            if iscell(colors.(names{i}))
                for j=1:length(colors.(names{i}))
                    all_colors = cat(1,all_colors,colors.(names{i}){j});
                    tick_names = cat(1,tick_names,[names{i},'(',num2str(j),')']);
                end
            elseif size(colors.(names{i}),1)>1
                for j=1:size(colors.(names{i}),1)
                    all_colors = cat(1,all_colors,colors.(names{i})(j,:));
                    tick_names = cat(1,tick_names,[names{i},'(',num2str(j),')']);
                end
            else
                all_colors = cat(1,all_colors,colors.(names{i}));
                tick_names = cat(1,tick_names,names{i});
            end
        end
        % Split colors up into groups of 6
        figure('Position',[224         913        800         600]);
        n = 8;
        rows = ceil(length(tick_names)/n);

        h = tight_subplot(rows,1,0.1);
        disp_vect = 1:length(tick_names);
        for i = 1:rows
            axes(h(i))
            imagesc(disp_vect((i-1)*n+1:min([end,(i-1)*n+n])),[1 length(tick_names)])
            set(h(i),'YTick',[])
            names = tick_names((i-1)*n+1:min([end,(i-1)*n+n]));
            set(h(i),'XTick',1:length(names),'XTickLabel',names,'FontSize',10)
            colormap(all_colors)            
        end
    end
end

if nargout<1
    assignin('base','colors',colors)
end