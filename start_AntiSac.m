function [rec, accu, status, exception] = start_AntiSac(opts)
arguments
    opts.SkipSyncTests (1,1) {mustBeNumericOrLogical} = false
end

% ---- configure exception ----
status = 0;
exception = [];
% PTB硬件bug，不同电脑会有不同鬼畜按键
[ keyIsDown, ~, keyCode ] = KbCheck;
keyCode = find(keyCode, 1);
if keyIsDown
    ignoreKey=keyCode;
    DisableKeysForKbCheck(ignoreKey);
end

% ---- configure sequence ----
config = readtable(fullfile("AntiSac_config", "AntiSac.xlsx"));
rec = config;
rec.resp = nan(height(config), 1);
rec.rt = nan(height(config), 1);
rec.score = nan(height(config), 1);
rec.onset_real = nan(height(config), 1);
timing = struct( ...
    'iti', 0.15, ... % inter-trial-interval
    'tdur', 3, ...
    'cue_dur', 0.15, ...
    'tar_dur', 0.175); % trial duration

load 'AntiSac_config/target.mat' target 
load 'AntiSac_config/mask' mask1
cue = 128 * ones(24);
cue_size = size(cue);
target_size = size(target{1,1});
tmp = zeros(height(config)+1, 5);
% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% do not skip synchronization test to make sure timing is accurate
old_sync = Screen('Preference', 'SkipSyncTests', double(opts.SkipSyncTests));
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen));
% PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
KbName('UnifyKeyNames')
keys={'1','2','3','4'};

keys1 = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'left', KbName('1!'), ...
    'up', KbName('2@'), ...
    'down', KbName('3#'), ...
    'right', KbName('4$'));

startSecs = GetSecs;
% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
     % open a window and set its background color as black
    [window_ptr, window_rect] = PsychImaging('OpenWindow', ...
        screen, BlackIndex(screen));
    [xcenter, ycenter] = RectCenter(window_rect);

    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % display welcome/instr screen and wait for a press of 's' to start
    sq=imread('AntiSac_config\InstructionAntiSac.jpg','jpg');  %%% instruction 
    tex=Screen('MakeTexture',window_ptr,sq);
    Screen('DrawTexture',window_ptr,tex);
    Screen('Flip',window_ptr);   % show stim, return flip time

    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        ignoreKey=keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end

    while ~early_exit
        % here we should detect for a key press and release
        [~, key_code] = KbStrokeWait(-1);
        if key_code(keys1.start)
            % start_time = resp_timestamp;
            break
        elseif key_code(keys1.exit)
            early_exit = true;
        end
    end

    % main experiment
    for trail_order = 1:height(config)
        this_trial = config(trail_order, :);
        DrawFormattedText(window_ptr, '+', 'center', 'center', WhiteIndex(window_ptr));
        WaitTill(GetSecs + ifi);

    % stage1: fixation
        VBL=Screen('Flip',window_ptr); % waiting for the designed onset;
        tmp(trail_order,1) = VBL-startSecs; % fixation onset;

        imageData = cue;
        if this_trial.Location_Of == 1
            Screen(window_ptr,'PutImage',imageData, ...
                [xcenter+96*3,ycenter-round(cue_size(1)/2),xcenter+96*3+cue_size(2),ycenter+round(cue_size(1)/2)]);
        else 
            Screen(window_ptr,'PutImage',imageData, ...
                [xcenter-96*3-cue_size(2),ycenter-round(cue_size(1)/2),xcenter-96*3,ycenter+round(cue_size(1)/2)]);
        end

        % stage 2: cue
        WaitTill(VBL + this_trial.Fixation_Dur); 
        VBL = Screen('Flip',window_ptr); % fixation offset        
        tmp(trail_order,2) = VBL-startSecs; % fixation onset;
        
        % prepare target
        imageData = target{this_trial.Tar_Dir,1};
        if this_trial.Location_Of == 1
            Screen(window_ptr,'PutImage',imageData, ...
                [xcenter-96*3.625-target_size(2),ycenter-round(target_size(1)/2),xcenter-96*3.625,ycenter+round(target_size(1)/2)]);
        else
            Screen(window_ptr,'PutImage',imageData, ...
                [xcenter+96*3.625,ycenter-round(target_size(1)/2),xcenter+96*3.625+target_size(2),ycenter+round(target_size(1)/2)]);
        end

        % stage 3: target
        WaitTill(VBL + timing.cue_dur); % cue duration
        VBL = Screen('Flip', window_ptr); % target onset;
        tmp(trail_order,3) = VBL-startSecs; % target onset;
        rec.onset_real(trail_order) = tmp(1,3);% record the onset of each trial, useful for fMRI study

        %prepare mask
        imageData = mask1;
        if this_trial.Location_Of == 1
            Screen(window_ptr, 'PutImage', imageData, ...
                [xcenter-96*3.625-target_size(2),ycenter-round(target_size(1)/2),xcenter-96*3.625,ycenter+round(target_size(1)/2)]);
        else
            Screen(window_ptr,'PutImage',imageData, ...
                [xcenter+96*3.625,ycenter-round(target_size(1)/2),xcenter+96*3.625+target_size(2),ycenter+round(target_size(1)/2)]);
        end
        
        % stage 4: mask
        WaitTill(VBL + timing.tar_dur);
        VBL=Screen('Flip', window_ptr); % mask onset;
        tmp(trail_order,4) = VBL-startSecs; % mask onset;

        % now get keys
        [key, timeSec] = WaitTill(VBL + timing.tdur, keys, 1);
        Screen('Flip', window_ptr);
        resp = find(strcmp(keys,key)==1);
        if ~isempty(key)
            
            rec.resp(trail_order) = resp;
            rec.rt(trail_order) = timeSec- tmp(trail_order,3)-startSecs;
            rec.score(trail_order) = rec.Tar_Dir(trail_order)==rec.resp(trail_order);
        end
    end
    accu = sum(rec{:, 7} == 1) / height(config);
       




catch exception
    status = -1;
end

% --- post presentation jobs
Screen('Close');
sca;
% enable character input and show mouse cursor
ListenChar;
ShowCursor;

% ---- restore preferences ----
Screen('Preference', 'VisualDebugLevel', old_visdb);
Screen('Preference', 'SkipSyncTests', old_sync);
Screen('Preference', 'TextRenderer', old_text_render);
Priority(old_pri);

if ~isempty(exception)
    rethrow(exception)
end
end