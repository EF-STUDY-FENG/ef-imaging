%%% --- Main Program --- %%%
subID = 1000; % subject ID
% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
config = readtable(fullfile("config", "numlet.xlsx"));
rec = config;
rec.onset_real = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 2.5); % trial duration

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% sync tests are recommended but may fail
old_sync = Screen('Preference', 'SkipSyncTests', double(opts.SkipSyncTests));
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen));
% PsychDebugWindowConfiguration([], 0.1);
