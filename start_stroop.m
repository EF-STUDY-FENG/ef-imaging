function [rec, status, exception] = start_stroop(run, start, rti, window_ptr, window_rect, prac)
   
% ---- configure exception ----
status = 0;
exception = [];
% accu = 0.00;

% ---- configure sequence ----
if nargin > 5 && prac == 1
    config = readtable(fullfile("config_prac", "stroop_prac.xlsx"));
else
    TaskFile = sprintf('stroop_run%d.xlsx', run);
    config = readtable(fullfile("config/stroop", TaskFile));
end
config.onset = config.onset + rti;
rec = config;
rec.onset_real = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);

timing = struct(...
    'iti', 0.5, ... 
    'tdur', 2.5); 

imageFolder = 'stimuli/stroop_stimuli';

% ---- keyboard settings ----
keys = struct(...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
     'red', KbName('1!'), ...
    'yellow', KbName('2@'), ...
    'blue', KbName('3#'), ...
    'green', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;

try
    % get screen center
    [xcenter, ycenter] = RectCenter(window_rect);

    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
        this_trial = config(trial_order, :);

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        stim_onset = start + this_trial.onset;
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
                Img = fullfile(imageFolder, this_trial.sti{1});
                Image = imread(Img);
                Texture = Screen('MakeTexture', window_ptr, Image);
                [imgHeight, imgWidth, ~] = size(Image);
                Rect = CenterRectOnPoint([0 0 imgWidth imgHeight], xcenter, ycenter);
                Screen('DrawTexture', window_ptr, Texture, [], Rect);
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
            valid_names = {'red', 'yellow', 'blue', 'green'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
        end
        score = strcmp(rec.color(trial_order), resp);
        rec.onset_real(trial_order) = onset_timestamp - start;
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end
    % accu = sum(rec{:, 12} == 1) / (height(config));
catch exception
    status = -1;
end

end