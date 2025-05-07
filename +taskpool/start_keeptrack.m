function [rec, early_exit, status, exception] = start_keeptrack(run, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
if nargin > 5 && prac == 1
    config = readtable(fullfile("config_prac", "keeptrack_prac.xlsx"));
else
    TaskFile = sprintf('keeptrack_run%d.xlsx', run);
    config = readtable(fullfile("config/keeptrack", TaskFile));
end
config.onset = config.onset + rti;
config.ans_onset = config.ans_onset + rti;
config.trial_end = config.trial_end + rti;
rec = config;
rec.cresp = cell(height(config), 1);
rec.onset_real = nan(height(config), 1);
rec.ansOnset_real = nan(height(config), 1);
rec.trialend_real = nan(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = cell(height(config), 1);
rec.cort = cell(height(config), 1);
timing = struct( ...
    'tdur', 1.5); % trial duration

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'num1', KbName('1!'), ...
    'num2', KbName('2@'), ...
    'num3', KbName('3#'), ...
    'num4', KbName('4$'));


% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % get screen center
    [~, ycenter] = RectCenter(window_rect);
    screenWidth = window_rect(3);

    % main experiment
    for trial = 1:height(config)
        if early_exit
            break
        end

        level = config.level(trial);
        this_trial = zeros(1, 2);
        this_trial(1) = config.onset(trial);
        this_trial(2) = config.ans_time(trial);
        eachnum_onset = (start+this_trial(1):timing.tdur:start+this_trial(1)+(level*3));
        eachblank_onset = (start+this_trial(1)+1:timing.tdur:start+this_trial(1)+(level*3-1.5)+1);

        % initialize stimulus timestamps
        ans_onset = start + this_trial(1) + level*3;
        trial_end = ans_onset + this_trial(2);
        onset_timestamp = nan;
        trialend_timestamp = nan;
        ansOnset_real = nan;


        % initialize responses
        corr = zeros(1, level);
        resp_list = zeros(1, level);
        resp_rt = zeros(1, level);

        % Generate numeric sequence
        positions = cell(1, level);
        correctAnswer = zeros(1, level);

        event.pos = nan(0,1);
        event.digit = nan(0,1);

        n=[];
        for i = 1:4
            for j = 1:4
                if rec.level(j) == level
                    n = str2num(strjoin(rec.run(j)));
                end
            end
        end
        for i = 1:level
            seq = randi([1 4], 1, n(i));
            positions{i} = seq;
            for num = 1:n(i)
                event.pos(end+1) = i;
                event.digit(end+1) = positions{i}(num);
            end
        end
        randOrder = randperm(length(event.pos));

        % now present stimuli and check user's response
        while ~early_exit
            [~, ~, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
            end
            % ---- configure stimuli ----
            xPos = linspace(screenWidth*0.3, screenWidth*0.7, level);
            yPos = ones(1, level) * ycenter;

            k = 1;
            for j = randOrder
                [~, ~, key_code] = KbCheck(-1);
                if key_code(keys.exit)
                    early_exit = true;
                    break
                end
                if early_exit
                    break
                end
                i = event.pos(j);
                digit = event.digit(j);
                correctAnswer(i) = digit;
                Screen('FillRect', window_ptr, 0);
                underline(xPos, yPos, level, window_ptr); % draw underline
                DrawFormattedText(window_ptr, num2str(event.digit(j)),...
                    'center', 'center', WhiteIndex(window_ptr), [], [], [], [], [],...
                    [xPos(event.pos(j))-50 yPos(event.pos(j))-50 xPos(event.pos(j))+50 yPos(event.pos(j))+50]);
                vbl = Screen('Flip', window_ptr, eachnum_onset(k));
                if isnan(onset_timestamp)
                    onset_timestamp = vbl;
                end
                underline(xPos, yPos, level, window_ptr);
                Screen('Flip', window_ptr, eachblank_onset(k));
                k = k + 1;
            end
            underline(xPos, yPos, level, window_ptr);
            Screen('Flip', window_ptr, eachnum_onset(k));
            break
        end
        % save answer on rec
        rec.cresp(trial) = cellstr(strjoin(arrayfun(@num2str, correctAnswer, 'UniformOutput', false), ','));
        while ~early_exit
            timeout = false;
            resp_timestamp = nan;
            for k = 1:level
                if GetSecs - ans_onset >= this_trial(2)
                    timeout = true;
                    break;
                end
                remaining_time = this_trial(2) - (GetSecs - ans_onset);
                [resp_code, timed_out, rt, ansOnset_real, resp_timestamp, window_ptr] = Flashing_U( ...
                    xPos, yPos, ycenter, level, ansOnset_real, resp_timestamp, window_ptr, k, resp_list, remaining_time);
                if any(resp_code(keys.exit))
                    early_exit = true;
                    timeout = true;
                    break;
                elseif timed_out
                    timeout = true;
                    break;
                end
                valid_names_1 = {'num1', 'num2', 'num3', 'num4'};
                valid_names = [1, 2, 3, 4];
                valid_codes = cellfun(@(x) keys.(x), valid_names_1);
                if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                    % pressed more than one key or invalid key
                    % resp = 'invalid';
                else
                    resp_rt(k) = round(rt*1000); % record as ms
                    resp = valid_names(valid_codes == find(resp_code));
                    corr(k) = double(resp == correctAnswer(k));
                    resp_list(k) = resp;
                end
                underline(xPos, yPos, level, window_ptr, k, resp_list)
            end
            if timeout
                corr(resp_rt == 0) = -1;
                score = corr;
                % rec.cort(trial) = -1;
                % rt = config.ans_time(trial);
            else
                score = corr;
                % rec.score(trial) = score;
            end
            vbl = Screen('Flip', window_ptr);
            if vbl < trial_end
                WaitSecs(trial_end - vbl);
            end
            vbl = Screen('Flip', window_ptr);
            if isnan(trialend_timestamp)
                trialend_timestamp = vbl;
            end
            rec.resp(trial) = cellstr(strjoin(arrayfun(@num2str, resp_list, 'UniformOutput', false), ','));
            rec.onset_real(trial) = onset_timestamp - start;
            rec.ansOnset_real(trial) = ansOnset_real - start;
            rec.trialend_real(trial) = trialend_timestamp - start;
            rec.rt(trial) = cellstr(strjoin(arrayfun(@num2str, resp_rt, 'UniformOutput', false), ','));
            rec.cort(trial) = cellstr(strjoin(arrayfun(@num2str, score, 'UniformOutput', false), ','));
            break
        end
    end

catch exception
    status = -1;
    fprintf('function call failed: %s\n', exception.message);
end

end

function underline(xPos, yPos, level, window_ptr, places, resp_list)

exampleNum = '0';
bounds = Screen('TextBounds', window_ptr, exampleNum);
textWidth = bounds(3);
textHeight = bounds(4);
underlinePadding = 5;  % Distance between underlines and digits
lineWidth = 5;         % Underlines thickness
underlinesSingle = zeros(level,4);
for i = 1:level
    underlinesSingle(i,:) = [xPos(i)-textWidth/2, yPos(i)+textHeight/2+underlinePadding,...
        xPos(i)+textWidth/2, yPos(i)+textHeight/2+underlinePadding];
end

if nargin > 4
    for j = 1:places
        Screen('DrawLine', window_ptr, WhiteIndex(window_ptr),...
            underlinesSingle(j,1), underlinesSingle(j,2),...
            underlinesSingle(j,3), underlinesSingle(j,4),...
            lineWidth);
        DrawFormattedText(window_ptr, num2str(resp_list(j)),...
            'center', 'center', WhiteIndex(window_ptr), [], [], [], [], [],...
            [xPos(j)-50 yPos(j)-50 xPos(j)+50 yPos(j)+50]);
    end
else
    for j = 1:level
        Screen('DrawLine', window_ptr, WhiteIndex(window_ptr),...
            underlinesSingle(j,1), underlinesSingle(j,2),...
            underlinesSingle(j,3), underlinesSingle(j,4),...
            lineWidth);
    end
end

end

function [keyCode, timed_out, rt, ansOnset_timestamp, resp_timestamp, window_ptr] = Flashing_U( ...
    xPos, yPos, ycenter, level, ansOnset_timestamp, resp_timestamp, window_ptr, current, resp_list, remaining_time)
keys = struct( ...
    'exit', KbName('Escape'));
timed_out = false;
% ansOnset_timestamp = nan;
rt = nan;
keyCode = nan;

exampleNum = '0';
bounds = Screen('TextBounds', window_ptr, exampleNum);
textWidth = bounds(3);
textHeight = bounds(4);
underlinePadding = 5;
lineWidth = 5;

underlinesSingle = zeros(level, 4);
for i = 1:level
    underlinesSingle(i, :) = [xPos(i)-textWidth/2, yPos(i)+textHeight/2+underlinePadding,...
        xPos(i)+textWidth/2, yPos(i)+textHeight/2+underlinePadding];
end

start_time = GetSecs;
end_time = start_time + remaining_time;
visibility = true;
keyIsDown = false;
early_exit = false;
keyPressTime = nan;
while ~keyIsDown && GetSecs < end_time && ~early_exit
    [keyIsDown, timestamp, keyCode] = KbCheck;
    if keyCode(keys.exit)
        early_exit = true;
    end

    Screen('FillRect', window_ptr, BlackIndex(window_ptr));
    instr_1 = sprintf('请输入位置 %d 的数字', current);
    DrawFormattedText(window_ptr, double(instr_1),...
        'center', ycenter-100, WhiteIndex(window_ptr));
    % Draw currently blinking underline
    if visibility
        Screen('DrawLine', window_ptr, WhiteIndex(window_ptr),...
            underlinesSingle(current,1), underlinesSingle(current,2),...
            underlinesSingle(current,3), underlinesSingle(current,4), lineWidth);
    end
    if current > 1
        underline(xPos, yPos, level, window_ptr, current-1, resp_list);
    end
    vbl = Screen('Flip', window_ptr);
    if isnan(ansOnset_timestamp)
        ansOnset_timestamp = vbl;
    end

    % Blinking every 0.5s
    if GetSecs - start_time >= 0.5
        visibility = ~visibility;
        start_time = GetSecs; % reset timer
    end

    if keyIsDown
        keyPressTime = timestamp; % 保存精确的按键时间
        break;
    end
end

if GetSecs >= end_time && ~keyIsDown
    timed_out = true;
end

if ~isnan(keyPressTime)
    if current == 1
        rt = keyPressTime - ansOnset_timestamp;
        resp_timestamp = keyPressTime;
    else
        rt = keyPressTime - resp_timestamp;
        resp_timestamp = keyPressTime;
    end
elseif timed_out
    rt = end_time - ansOnset_timestamp;
end
KbReleaseWait
end
