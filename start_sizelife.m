function [accu, rec, status, exception] = start_sizelife(run, window_ptr, window_rect, prac)
% arguments
%     opts.SkipSyncTests (1,1) {mustBeNumericOrLogical} = false
% end

% ---- configure exception ----
status = 0;
exception = [];
accu = 0.00;

% ---- configure sequence ----
if nargin > 3 && prac == 1
    config = readtable(fullfile("config_prac", "sizelife_prac.xlsx"));
else
    TaskFile = sprintf('sizelife_run%d.xlsx', run);
    config = readtable(fullfile("config/sizelife", TaskFile));
end
rec = config;
rec.onset_real = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 2.5); % trial duration

imageFolder = 'stimuli/sizelife_stimuli';       % figure folder

% % ---- configure screen and window ----
% % setup default level of 2
% PsychDefaultSetup(2);
% % screen selection
% screen_to_display = max(Screen('Screens'));
% % set the start up screen to black
% old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% % do not skip synchronization test to make sure timing is accurate
% old_sync = Screen('Preference', 'SkipSyncTests', 0);
% % use FTGL text plugin
% old_text_render = Screen('Preference', 'TextRenderer', 1);
% % set priority to the top
% old_pri = Priority(MaxPriority(screen_to_display));
% % PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'Y', KbName('1!'), ...
    'N', KbName('4$') );

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    %  % open a window and set its background color as black
    % [window_ptr, window_rect] = PsychImaging('OpenWindow', ...
    %     screen_to_display, BlackIndex(screen_to_display));
    % % [xcenter, ycenter] = RectCenter(window_rect);
    % % disable character input and hide mouse cursor
    % ListenChar(2);
    % HideCursor;
    % % set blending function
    % Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % % set default font name
    % Screen('TextFont', window_ptr, 'SimHei');
    % Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));
    % % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % ---- configure stimuli ----
    % r = CenterRect([0 0 1 1]*p.sz, window_rect);

    % display welcome/instr screen and wait for a press of 's' to start
    sq=imread('Instruction\sizelife.jpg');
    tex=Screen('MakeTexture',window_ptr,sq);
    Screen('DrawTexture',window_ptr,tex);
    Screen('Flip',window_ptr); 
    WaitSecs(4.5);
    vbl = Screen('Flip', window_ptr); 
    WaitSecs(0.5);
    start_time = vbl + 0.5;
    
    % while ~early_exit
    %     % here we should detect for a key press and release
    %     [resp_timestamp, key_code] = KbStrokeWait(-1);
    %     if key_code(keys.start)
    %         start_time = resp_timestamp;
    %         break
    %     elseif key_code(keys.exit)
    %         early_exit = true;
    %     end
    % end


    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
         this_trial = config(trial_order, :);
        % stim_str = [num2str(this_trial.shape), '    ', this_trial.color{:}];
        

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        stim_onset = start_time + this_trial.onset;
        stim_offset = stim_onset + timing.tdur;
        trial_end = stim_offset + timing.iti;
        onset_timestamp = nan;
        offset_timestamp = nan;

        % now present stimuli and check user's response
        while ~early_exit
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
                   centerImg_name = this_trial.pic;
                   topImg_name = this_trial.task;
                   centerImg = fullfile(imageFolder, centerImg_name);
                   topImg = fullfile(imageFolder, topImg_name);

                   % Ensure centerImg is a character vector or string scalar
                   if iscell(centerImg)
                       centerImg = centerImg{1};  
                   end

                   if iscell(topImg)
                      topImg = topImg{1};  % Extract cell content
                   end
                   centerImage = imread(centerImg);
                   topImage = imread(topImg);
                    
                   centerImage = imresize(centerImage, 0.44, "nearest");

                   % Create texture
                   centerTexture = Screen('MakeTexture', window_ptr, centerImage);
                   topTexture = Screen('MakeTexture', window_ptr, topImage);
                   [screenWidth, screenHeight] = Screen('WindowSize', window_ptr);

                   % Calculate dimensions for the center image while maintaining aspect ratio
                   centerWidth = size(centerImage, 2); 
                   centerHeight = size(centerImage, 1); 
                   centerRect = [0, 0, centerWidth, centerHeight];
                   centerRect = CenterRectOnPoint(centerRect, screenWidth / 2, screenHeight / 2);

                   % Calculate dimensions for the top image while maintaining aspect ratio
                   topWidth = size(topImage, 2); 
                   topHeight = size(topImage, 1); 
                   topRect = [0, 0, topWidth, topHeight];
                   topY = centerRect(2) - topHeight - 15;                  
                   topRect = CenterRectOnPoint(topRect, screenWidth/2, topY); 

                   % Draw the textures on the screen
                   Screen('DrawTexture', window_ptr, centerTexture, [], centerRect);
                   Screen('DrawTexture', window_ptr, topTexture, [], topRect);
                   vbl = Screen('Flip', window_ptr);
 
                if isnan(onset_timestamp)
                    onset_timestamp = vbl;
                end
            end
        end

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
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
        end
        score = strcmp(rec.cresp(trial_order), resp); 
        rec.onset_real(trial_order) = onset_timestamp - start_time;
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end
     accu = sum(rec{:, 10} == 1) / (height(config));
     % disp(['正确率: ', num2str(accu * 100), '%']);
catch exception
    status = -1;
end

% % --- post presentation jobs
% Screen('Close');
% sca;
% % enable character input and show mouse cursor
% ListenChar;
% ShowCursor;
% 
% % ---- restore preferences ----
% Screen('Preference', 'VisualDebugLevel', old_visdb);
% Screen('Preference', 'SkipSyncTests', old_sync);
% Screen('Preference', 'TextRenderer', old_text_render);
% Priority(old_pri);
% 
% if ~isempty(exception)
%     rethrow(exception)
% end
end