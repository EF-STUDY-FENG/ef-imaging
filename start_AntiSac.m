function [accu, rec, status, exception] = start_AntiSac(run, window_ptr, window_rect, prac)
% arguments
%     opts.SkipSyncTests (1,1) {mustBeNumericOrLogical} = false
% end

% ---- configure exception ----
status = 0;
exception = [];
accu = 0.00;

% ---- configure sequence ----
if nargin > 3 && prac == 1
    config = readtable(fullfile("config_prac", "AntiSac_prac.xlsx"));
else
    TaskFile = sprintf('AntiSac_run%d.xlsx', run);
    config = readtable(fullfile("config/AntiSac_config", TaskFile));
end
rec = config;
rec.onset_real = nan(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.cort = nan(height(config), 1);
timing = struct( ...
    'iti', 0.15, ... % inter-trial-interval
    'tdur', 1, ...1ss
    'cue_dur', 0.15, ...
    'tar_dur', 0.175); % trial duration

load 'AntiSac_config/target.mat' target 
load 'AntiSac_config/mask' mask1
for i=1:4
    target{i} = imresize(target{i}, 1.52, "nearest");
end
cue = 128 * ones(64);
cue_size = size(cue);
target_size = size(target{1,1});
tmp = zeros(height(config)+1, 5);
% % ---- configure screen and window ----
% % setup default level of 2
% PsychDefaultSetup(2);
% % screen selection
% screen = max(Screen('Screens'));
% % set the start up screen to black
% old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% % do not skip synchronization test to make sure timing is accurate
% old_sync = Screen('Preference', 'SkipSyncTests', 1);
% % use FTGL text plugin
% old_text_render = Screen('Preference', 'TextRenderer', 1);
% % set priority to the top
% old_pri = Priority(MaxPriority(screen));
% % PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
KbName('UnifyKeyNames')

keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'left', KbName('1!'), ...
    'up', KbName('2@'), ...
    'down', KbName('3#'), ...
    'right', KbName('4$'));

% start_time = GetSecs;
% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    %  % open a window and set its background color as black
    % [window_ptr, window_rect] = PsychImaging('OpenWindow', ...
    %     screen, BlackIndex(screen));
    [xcenter, ycenter] = RectCenter(window_rect);
    % 
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
    % 
    % % ---- configure stimuli ----
    % ratio_size = 0.3;
    % stim_window = [0, 0, RectWidth(window_rect), ratio_size * RectHeight(window_rect)];

    % display welcome/instr screen and wait for a press of 's' to start
    Inst = imread('Instruction\AntiSac.jpg');  %%% instruction 
    tex=Screen('MakeTexture', window_ptr, Inst);
    Screen('DrawTexture', window_ptr, tex);
    Screen('Flip', window_ptr);   % show stim, return flip time
    WaitSecs(4.5);
    vbl = Screen('Flip', window_ptr); 
    WaitSecs(0.5);
    start_time = vbl + 0.5;

    % while ~early_exit
    %     % here we should detect for a key press and release
    %     [~, key_code] = KbStrokeWait(-1);
    %     if key_code(keys.start)
    %         vbl = Screen('Flip',window_ptr);
    %         pause(0.5)
    %         start_time = vbl + 5;
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
        % stim_str = [this_trial.letter{:}];

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        fixation_onset = start_time + this_trial.onset;
        cue_onset = fixation_onset + this_trial.Fixation_Dur;
        tar_onset = cue_onset + timing.cue_dur;
        mask_onset = tar_onset + timing.tar_dur;
        trial_end = mask_onset + timing.tdur;
        fixation_timestamp = nan;
        cue_timestamp = nan;
        tar_timestamp = nan;
        mask_timestamp = nan;


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
            if timestamp >= trial_end - 0.5 * ifi
                    % remaining time is not enough for a new flip
                    break
            end
            if timestamp >= fixation_onset + 0.5 * ifi && timestamp < cue_onset - 0.5 * ifi
               DrawFormattedText(window_ptr, '+', 'center', 'center', WhiteIndex(window_ptr)); 
               vbl = Screen('Flip', window_ptr);
               if isnan(fixation_timestamp)
                   fixation_timestamp = vbl;
                   tmp(trial_order, 1) = vbl - start_time;
               end
            elseif timestamp >= cue_onset + 0.5 * ifi && timestamp < tar_onset - 0.5 * ifi
                % imageData = cue;
                if this_trial.Location_Of == 1
                    
                    Screen('FillRect', window_ptr, GrayIndex(window_ptr), ...
                        [xcenter+96*3,ycenter-round(cue_size(1)/2),xcenter+96*3+cue_size(2),ycenter+round(cue_size(1)/2)]);
                    % Screen(window_ptr,'PutImage',imageData, ...
                    %     [xcenter+96*3,ycenter-round(cue_size(1)/2),xcenter+96*3+cue_size(2),ycenter+round(cue_size(1)/2)]);
                else 
                    Screen('FillRect', window_ptr, GrayIndex(window_ptr), ...
                        [xcenter-96*3-cue_size(2),ycenter-round(cue_size(1)/2),xcenter-96*3,ycenter+round(cue_size(1)/2)]);

                    % Screen(window_ptr,'PutImage',imageData, ...
                    %     [xcenter-96*3-cue_size(2),ycenter-round(cue_size(1)/2),xcenter-96*3,ycenter+round(cue_size(1)/2)]);
                end
                vbl = Screen('Flip', window_ptr);
                if isnan(cue_timestamp)
                    cue_timestamp = vbl; % cue offset;
                    tmp(trial_order, 2) = vbl - start_time;% cue onset;
                end
            elseif timestamp >= tar_onset + 0.5 * ifi && timestamp < mask_onset - 0.5 * ifi
                imageData = target{this_trial.Tar_Dir,1};
                if this_trial.Location_Of == 1
                    Screen(window_ptr,'PutImage',imageData, ...
                        [xcenter-96*3.625-target_size(2),ycenter-round(target_size(1)/2),xcenter-96*3.625,ycenter+round(target_size(1)/2)]);
                else
                    Screen(window_ptr,'PutImage',imageData, ...
                        [xcenter+96*3.625,ycenter-round(target_size(1)/2),xcenter+96*3.625+target_size(2),ycenter+round(target_size(1)/2)]);
                end
                vbl = Screen('Flip', window_ptr);
                if isnan(tar_timestamp) 
                    tar_timestamp = vbl; % tar offset;
                    tmp(trial_order, 3) = vbl - start_time;% tar onset;
                end
            elseif timestamp >= mask_onset + 0.5 * ifi && timestamp < trial_end - 0.5 * ifi
                imageData = mask1;
                if this_trial.Location_Of == 1
                    Screen(window_ptr,'PutImage',imageData, ...
                        [xcenter-96*3.625-target_size(2),ycenter-round(target_size(1)/2),xcenter-96*3.625,ycenter+round(target_size(1)/2)]);
                else
                    Screen(window_ptr,'PutImage',imageData, ...
                        [xcenter+96*3.625,ycenter-round(target_size(1)/2),xcenter+96*3.625+target_size(2),ycenter+round(target_size(1)/2)]);
                end
                vbl = Screen('Flip', window_ptr);
                if isnan(mask_timestamp) 
                    mask_timestamp = vbl; % tar offset;
                    tmp(trial_order, 4) = vbl - start_time;% tar onset;
                end
            end
        end

        % analyze user's response
        if ~resp_made
            % resp_raw = '';
            resp = '';
            rt = 0;
        else 
            % resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'left', 'up', 'down', 'right'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                % pressed more than one key or invalid key
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - mask_timestamp;
        end
        score = strcmp(rec.cresp(trial_order), resp);
        rec.onset_real(trial_order) = fixation_timestamp - start_time;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;

    
    end
    accu = sum(rec{:, 10} == 1) / height(config);   




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