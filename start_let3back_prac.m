function [accu, rec, status, exception] = start_let3back_prac(opts)
arguments
    opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
end

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
config = readtable(fullfile("config", "let3back_prac.xlsx"));
rec = config;
rec.onset_real = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.cort = nan(height(config),1);
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 1.5,...
    'feedback', 0.5); % trial duration

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

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'Y', KbName('1!'), ...
    'N', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % open a window and set its background color as black
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
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

    % ---- configure stimuli ----
    ratio_size = 0.3;
    stim_window = [0, 0, RectWidth(window_rect), ratio_size * RectHeight(window_rect)];

    % display welcome/instr screen and wait for a press of 's' to start
    introImg = imread(fullfile('intro_pic', 'let3back.jpg'));
    tex = Screen('MakeTexture', window_ptr, introImg);
    Screen('DrawTexture', window_ptr, tex);
    Screen('Flip', window_ptr);
    % solve keystroke bug 
     [ keyIsDown, ~, keyCode ] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        ignoreKey=keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end
    while ~early_exit
        % here we should detect for a key press and release
        [resp_timestamp, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            vbl = Screen('Flip',window_ptr);
            WaitSecs(0.5);
            start_time = vbl + 0.5;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
        this_trial = config(trial_order, :);
        stim_str = [this_trial.letter{:}];

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        if trial_order == 1 
            stim_onset = start_time;
        else 
            lastTrail_end = trial_end;
            stim_onset = lastTrail_end;
        end
        stim_offset = stim_onset + timing.tdur;
        feedback_onset = stim_offset + timing.iti;
        trial_end = feedback_onset + timing.feedback;
        onset_timestamp = nan;
        offset_timestamp = nan;
        key_pressed = false;
        % now present stimuli and check user's response
        while ~key_pressed && ~early_exit
            [key_pressed, timestamp, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end
            if key_pressed
                if ~resp_made
                    resp_code = key_code;
                    resp_timestamp = timestamp;
                end
                resp_made = true;
            end
            if timestamp > trial_end - 0.5 * ifi
                % remaining time is not enough for a new flip
                break
            end
            if timestamp < stim_onset || timestamp >= stim_offset
                vbl = Screen('Flip', window_ptr);
                if timestamp >= stim_offset && isnan(offset_timestamp)
                    offset_timestamp = vbl;
                end
            elseif timestamp < stim_offset - 0.5 * ifi
                DrawFormattedText(window_ptr, stim_str, ...
                    'center', 'center', ...
                    WhiteIndex(window_ptr), [], [], [], [], [], ...
                    CenterRectOnPoint(stim_window, xcenter, ycenter));
                vbl = Screen('Flip', window_ptr);
                if isnan(onset_timestamp)
                    onset_timestamp = vbl;
                end
            end
        end
        KbReleaseWait;

        % analyze user's response
        if ~resp_made
            resp_raw = '';
            resp = '';
            rt = 0;
        else
            resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'Y', 'N'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                % pressed more than one key or invalid key
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
        end
        score = strcmp(rec.cresp(trial_order), resp);
        if ~score && trial_order > 3
            instr = '错误!';
            DrawFormattedText(window_ptr, double(instr), 'center', 'center', WhiteIndex(window_ptr));
            vbl = Screen('Flip', window_ptr);
            pause(0.75);
            if vbl+0.75 < trial_end
                Screen('Flip', window_ptr)
                pause(trial_end - (vbl+0.75));
            end
        else 
            Screen('Flip', window_ptr);
            pause(trial_end - vbl);
        end
        rec.onset_real(trial_order) = onset_timestamp - start_time;
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end
    accu = sum(rec{:, 8} == 1) / (height(config)-3);
    instr = sprintf('你的正确率是： %.2f%\n请按Esc键退出', accu);
    DrawFormattedText(window_ptr, double(instr), 'center', 'center', WhiteIndex(window_ptr));
    Screen('Flip', window_ptr);
    while ~early_exit
        % here we should detect for a key press and release
        [~, key_code] = KbStrokeWait(-1);
        if key_code(keys.exit)
            early_exit = true;
        end
    end
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
