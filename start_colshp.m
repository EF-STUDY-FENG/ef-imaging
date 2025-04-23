function [rec, status, exception] = start_colshp(~, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];
% accu = 0.00;

% ---- configure sequence ----
if nargin > 5 && prac == 1
    p.trial = 10;
else
    p.trial = 20;
end
valid_names = {'Left', 'Right'};
rec = table();
rec.Trial = (1:p.trial)';
rec.shape = randi([1,2], p.trial, 1);
rec.color = randi([1,2], p.trial, 1);
rec.task = randi([1,2], p.trial, 1);
rec.cresp = cell(p.trial, 1);
for i = 1:p.trial
    if rec.task(i) == 1
        rec.cresp(i) = valid_names(rec.shape(i));
    else
        rec.cresp(i) = valid_names(rec.color(i));
    end
end
rec.onset = (rti:3:rti+3*(p.trial-1))';
rec.onset_real = nan(p.trial, 1);
rec.resp_raw = cell(p.trial, 1);
rec.resp = cell(p.trial, 1);
rec.rt = nan(p.trial, 1);
rec.cort = nan(p.trial,1);
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 2.5); % trial duration
p.color = [1 0 0; 0 1 0] * 255; % red / green
p.sz = 200; %size
cuetxt = {'XZ'; 'YS'}; %'XZ':shape task,'YS':color task

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'Left', KbName('1!'), ...
    'Right', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;

try
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % configure shape location
    r = CenterRect([0 0 1 1]*p.sz, window_rect);
    circle = CenterRect([0 0 1 1]*p.sz*0.8, window_rect);
    triagl = [mean(r([1 3])) r(2)+p.sz*0.1;
          r(1)+p.sz*0.1  r(4)-p.sz*0.1;
          r(3)-p.sz*0.1  r(4)-p.sz*0.1];

    % main experiment
    for trial_order = 1:p.trial
        if early_exit
            break
        end
        this_trial = rec(trial_order, :);
        r = CenterRect([0 0 1 1]*p.sz, window_rect); 

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
                Screen('TextSize', window_ptr, 72);
                DrawFormattedText(window_ptr, strjoin(cuetxt(this_trial.task)), 'center', r(2)-100, ...
                    WhiteIndex(window_ptr));
                vbl = Screen('Flip', window_ptr, [], 1);
                if this_trial.shape == 1
                    Screen('FrameOval', window_ptr, p.color(this_trial.color,:), circle, 4);
                else
                    Screen('FramePoly', window_ptr, p.color(this_trial.color,:), triagl, 4);
                end
                
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
            valid_names = {'Left', 'Right'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
        end
        score = strcmp(rec.cresp(trial_order), resp);
        rec.onset_real(trial_order) = onset_timestamp - start;
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end

catch exception
    status = -1;
end

end
