function [rec, early_exit, status, exception] = start_antisac(run, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
if nargin > 5 && prac == 1
    config = readtable(fullfile("config_prac", "antisac_prac.xlsx"));
else
    TaskFile = sprintf('antisac_run%d.xlsx', run);
    config = readtable(fullfile("config/antisac", TaskFile));
end
config.onset = config.onset + rti;
rec = config;
rec.onset_real = nan(height(config), 1);
rec.trialend_real = nan(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.cort = nan(height(config), 1);
timing = struct( ...
    'iti', 0.15, ... % inter-trial-interval
    'tdur', 1, ...
    'cue_dur', 0.15, ...
    'tar_dur', 0.175); % trial duration

tmp = zeros(height(config)+1, 5);

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'left', KbName('1!'), ...
    'up', KbName('2@'), ...
    'down', KbName('3#'), ...
    'right', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % get screen center, Width and Height
    [~, ycenter] = RectCenter(window_rect);
    [screenWidth, screenHeight] = Screen('WindowSize', window_ptr);
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % ---- configure stimuli ----
    matrixSize = 0.06 * screenHeight;
    xLeftCenter = 0.3 * screenWidth;
    xRightCenter = 0.7 * screenWidth;
    leftMatrixRect = [xLeftCenter - matrixSize/2, ycenter - matrixSize/2, ...
        xLeftCenter + matrixSize/2, ycenter + matrixSize/2];
    rightMatrixRect = [xRightCenter - matrixSize/2, ycenter - matrixSize/2, ...
        xRightCenter + matrixSize/2, ycenter + matrixSize/2];

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
        fixation_onset = start + this_trial.onset;
        cue_onset = fixation_onset + this_trial.Fixation_Dur;
        tar_onset = cue_onset + timing.cue_dur;
        mask_onset = tar_onset + timing.tar_dur;
        trial_end = mask_onset + timing.tdur;
        fixation_timestamp = nan;
        tar_timestamp = nan;

        % now present stimuli
        % present the fixation '+'
        DrawFormattedText(window_ptr, '+', 'center', 'center', WhiteIndex(window_ptr));
        vbl = Screen('Flip', window_ptr, fixation_onset+0.5*ifi);
        if isnan(fixation_timestamp)
            fixation_timestamp = vbl;
            tmp(trial_order, 1) = vbl - start; % fixation onset
        end

        % present a gray square as cue
        if this_trial.Location_Of == 1
            Screen('FillRect', window_ptr, GrayIndex(window_ptr), rightMatrixRect);
        else
            Screen('FillRect', window_ptr, GrayIndex(window_ptr), leftMatrixRect);
        end
        vbl = Screen('Flip', window_ptr, cue_onset+0.5*ifi);

        tmp(trial_order, 2) = vbl - start; % cue onset;

        % check user's response
        while ~early_exit
            [key_pressed, timestamp, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end
            if timestamp > tar_onset
                if key_pressed
                    if ~resp_made
                        resp_code = key_code;
                        resp_timestamp = timestamp;
                    end
                    resp_made = true;
                end
            end
            if timestamp >= trial_end - 0.5 * ifi
                trialend_timestamp = timestamp;
                % remaining time is not enough for a new flip
                break
            end
            if timestamp >= tar_onset + 0.5 * ifi && timestamp < mask_onset - 0.5 * ifi
                % present a arrow as target
                arrow(matrixSize, window_ptr, this_trial.Location_Of, this_trial.Tar_Dir)
                vbl = Screen('Flip', window_ptr);
                if isnan(tar_timestamp)
                    tar_timestamp = vbl;
                    tmp(trial_order, 3) = vbl - start; % tar onset;
                end
            elseif timestamp >= mask_onset + 0.5 * ifi && timestamp < trial_end - 0.5 * ifi
                % present a white square as mask to block the target
                if this_trial.Location_Of == 1
                    Screen('FillRect', window_ptr, WhiteIndex(window_ptr), leftMatrixRect);
                else
                    Screen('FillRect', window_ptr, WhiteIndex(window_ptr), rightMatrixRect);
                end
                vbl = Screen('Flip', window_ptr);
                tmp(trial_order, 4) = vbl - start; % mask onset;
            end
        end

        % analyze user's response
        if ~resp_made
            resp = '';
            rt = 0;
            score = -1;
        else
            valid_names = {'left', 'up', 'down', 'right'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                % pressed more than one key or invalid key
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - tar_timestamp;
            score = strcmp(rec.cresp(trial_order), resp);
        end
        rec.onset_real(trial_order) = fixation_timestamp - start;
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

function arrow(matrixSize, window_ptr, loc, dir)
[screenWidth, screenHeight] = Screen('WindowSize', window_ptr);
ycenter = screenHeight / 2;
if loc == 1
    xcenter = 0.3 * screenWidth;
else
    xcenter = 0.7 * screenWidth;
end

squ = [xcenter - matrixSize/2, ycenter - matrixSize/2, ...
    xcenter + matrixSize/2, ycenter + matrixSize/2];

arrH1 = 0.9 * matrixSize;
arrH2 = 0.4 * matrixSize;
arrW1 = 0.8 * matrixSize;
arrW2 = 0.15 * matrixSize;

switch dir
    case 1 % left arrow
        arrowPoints = [
            xcenter - arrH1/2,       ycenter          ;
            xcenter          ,       ycenter + arrW1/2;
            xcenter - arrH2/2,       ycenter + arrW2/2;
            xcenter + arrH1/2,       ycenter + arrW2/2;
            xcenter + arrH1/2,       ycenter - arrW2/2;
            xcenter - arrH2/2,       ycenter - arrW2/2;
            xcenter          ,       ycenter - arrW1/2;
            ];
    case 2 % up arrow
        arrowPoints = [
            xcenter,                 ycenter - arrH1/2;
            xcenter - arrW1/2,       ycenter          ;
            xcenter - arrW2/2,       ycenter - arrH2/2;
            xcenter - arrW2/2,       ycenter + arrH1/2;
            xcenter + arrW2/2,       ycenter + arrH1/2;
            xcenter + arrW2/2,       ycenter - arrH2/2;
            xcenter + arrW1/2,       ycenter          ;
            ];
    case 3 % down arrow
        arrowPoints = [
            xcenter,                 ycenter + arrH1/2;
            xcenter - arrW1/2,       ycenter          ;
            xcenter - arrW2/2,       ycenter + arrH2/2;
            xcenter - arrW2/2,       ycenter - arrH1/2;
            xcenter + arrW2/2,       ycenter - arrH1/2;
            xcenter + arrW2/2,       ycenter + arrH2/2;
            xcenter + arrW1/2,       ycenter          ;
            ];
    case 4 % right arrow
        arrowPoints = [
            xcenter + arrH1/2,       ycenter          ;
            xcenter          ,       ycenter + arrW1/2;
            xcenter + arrH2/2,       ycenter + arrW2/2;
            xcenter - arrH1/2,       ycenter + arrW2/2;
            xcenter - arrH1/2,       ycenter - arrW2/2;
            xcenter + arrH2/2,       ycenter - arrW2/2;
            xcenter          ,       ycenter - arrW1/2;
            ];
end

Screen('FillRect', window_ptr, WhiteIndex(window_ptr), squ);
Screen('FillPoly', window_ptr, BlackIndex(window_ptr), arrowPoints);
end
