function [rec, status, exception] = start_spt2back(run, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
p.nback = 2;
p.nSquare = 10;
p.squareSize = 64;

if nargin > 5 && prac == 1
    load ('config_prac/spt2back', 'x', 'y', 'squx', 'squy', 'ind');
    config = readtable(fullfile("config_prac", "spt2back_prac.xlsx"));
else
    loc_config = fullfile("stimuli/spt2back", sprintf('run%d.mat', run));
    load (loc_config, 'x', 'y', 'squx', 'squy', 'ind');
    TaskFile = sprintf('spt2back_run%d.xlsx', run);
    config = readtable(fullfile("config/spt2back", TaskFile));
end
config.onset = config.onset + rti +0.5;
rec = config;
rec.onset_real = nan(height(config), 1);
rec.trialend_real = nan(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.cort = nan(height(config), 1);


timing = struct( ...
    'iti', 1.5, ... % inter-trial-interval
    'tdur', 0.5); % trial duration

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
    % get each square location
    x = x + window_rect(3)/2 + squx; % rand(5)*p.squareSize - p.squareSize*5;
    y = y + window_rect(4)/2 + squy; % rand(5)*p.squareSize - p.squareSize*5;

    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);
    
    % main experiment
    rects = [x(ind) y(ind) x(ind)+p.squareSize y(ind)+p.squareSize]';
    Screen('FrameRect', window_ptr, 255, rects, 3);
    Screen('Flip', window_ptr, config.onset(1)-0.5);

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
                trialend_timestamp = timestamp;
                % remaining time is not enough for a new flip
                break
            end
            if timestamp < stim_onset || timestamp >= stim_offset
                Screen('FrameRect', window_ptr, 255, rects, 3);
                vbl = Screen('Flip', window_ptr);
                if timestamp >= stim_offset && isnan(offset_timestamp)
                    offset_timestamp = vbl;
                end
            elseif timestamp < stim_offset - 0.5 * ifi
                Screen('FrameRect', window_ptr, 255, rects, 3);
                Screen('FillRect', window_ptr, 128, rects(:,config.loc(trial_order))');
                vbl = Screen('Flip', window_ptr);
                if isnan(onset_timestamp)
                    onset_timestamp = vbl;
                end
            end
        end

        % analyze user's response
        if ~resp_made
            % resp_raw = '';
            resp = '';
            rt = 0;
            if trial_order > 2
                score = -1;
            else
                score = 0;
            end
        else
            valid_names = {'Y', 'N'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
            score = strcmp(rec.cresp(trial_order), resp);
        end
        rec.onset_real(trial_order) = onset_timestamp - start;
        rec.trialend_real(trial_order) = trialend_timestamp - start;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end

catch exception
    status = -1;
    fprintf('function call failed: %s\n', exception.message);
end

end
