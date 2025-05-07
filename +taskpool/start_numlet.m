function [rec, early_exit, status, exception] = start_numlet(run, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ---- %
if nargin > 5 && prac == 1
    config = readtable(fullfile("config_prac", "numlet_prac.xlsx"));
else
    TaskFile = sprintf('numlet_run%d.xlsx', run);
    config = readtable(fullfile("config/numlet", TaskFile));
end
config.onset = config.onset + rti;
rec = config;
rec.onset_real = nan(height(config), 1);
rec.trialend_real = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.cort = nan(height(config),1);
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 2.5); % trial duration

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'left', KbName('1!'), ...
    'right', KbName('4$'));


% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % get screen center
    [xcenter, ycenter] = RectCenter(window_rect);
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);
    %
    % % ---- configure stimuli ----
    ratio_size = 0.3;
    squareWidth = 0.13;
    squareHeight = 0.09;
    stim_window = [0, 0, RectWidth(window_rect), ratio_size * RectHeight(window_rect)];
    SquareFig = [0 0 squareWidth*RectWidth(window_rect) squareHeight*RectHeight(window_rect)];

    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
        this_trial = config(trial_order, :);
        stim_str = [num2str(this_trial.number), '    ', this_trial.letter{:}];

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
                trialend_timestamp = timestamp;
                % remaining time is not enough for a new flip
                break
            end
            if timestamp < stim_onset || timestamp >= stim_offset
                vbl = Screen('Flip', window_ptr);
                if timestamp >= stim_offset && isnan(offset_timestamp)
                    offset_timestamp = vbl;
                end
            elseif timestamp < stim_offset - 0.5 * ifi

                switch this_trial.task{:}
                    case 'number' % upper part
                        ycenter_stim = ycenter - ratio_size / 2 * RectHeight(window_rect);
                    case 'letter' % lower part
                        ycenter_stim = ycenter + ratio_size / 2 * RectHeight(window_rect);
                end
                DrawFormattedText(window_ptr, stim_str, ...
                    'center', 'center', ...
                    WhiteIndex(window_ptr), [], [], [], [], [], ...
                    CenterRectOnPoint(stim_window, xcenter, ycenter_stim));
                SquareRect = CenterRectOnPointd(SquareFig, xcenter, ycenter_stim);
                Screen('FrameRect', window_ptr, WhiteIndex(window_ptr), SquareRect, 5);
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
            score = -1;
        else
            resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'left', 'right'};
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
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end

catch exception
    status = -1;
    fprintf('function call failed: %s\n', exception.message);
end

end
