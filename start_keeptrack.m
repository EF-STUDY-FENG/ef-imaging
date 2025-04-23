function [rec, status, exception] = start_keeptrack(run, start, rti, window_ptr, window_rect, prac)

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
p.maxTri = 4;
p.level = 3;
% Errors = 0;
config = readtable(fullfile("config/keeptrack", 'keeptrack.xlsx'));
config.onset = config.onset + rti;
rec = table();
rec.level(1:4) = config.level(1:4);
rec.offset_real = nan(height(rec), 1);

if nargin > 5 && prac == 1
    rec.run(1:4) = eval(sprintf('config.prac(1:4)'));
else
    rec.run(1:4) = eval(sprintf('config.run%d(1:4)',run));
end
rec.score = nan(p.maxTri, 1);
timing = struct( ...
    'iti', 1.0, ... % inter-trial-interval
    'tdur', 0.5); % trial duration

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
    for trial = 1:p.maxTri
        if early_exit
            break
        end

        this_trial = zeros(1, 2);
        this_trial(1) = config.onset(trial);
        this_trial(2) = config.ans_time(trial);

        % initialize stimulus timestamps
        ans_onset = start + this_trial(1) + p.level*3;
        trial_end = ans_onset + this_trial(2);
        onset_timestamp = nan;

        % initialize responses
        corr = [];
        resp_list = nan(p.level, 1); 

        % Generate numeric sequence
        positions = cell(1, p.level);
        correctAnswer = zeros(1, p.level);

        event.pos = nan(0,1);
        event.digit = nan(0,1);

        n=[];
        for i = 1:4
            for j = 1:4
                if rec.level(j) == p.level
                    n = str2num(strjoin(rec.run(j)));
                end
            end
        end
        for i = 1:p.level
            % n = randi([1,3]);
            seq = randi([1 4], 1, n(i));
            positions{i} = seq;
            % correctAnswer(i) = seq(end); 
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
            xPos = linspace(screenWidth*0.3, screenWidth*0.7, p.level);
            yPos = ones(1, p.level) * ycenter;
        
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
                underline(xPos, yPos, p.level, window_ptr); % draw underline
                DrawFormattedText(window_ptr, num2str(event.digit(j)),...
                        'center', 'center', WhiteIndex(window_ptr), [], [], [], [], [],...
                        [xPos(event.pos(j))-50 yPos(event.pos(j))-50 xPos(event.pos(j))+50 yPos(event.pos(j))+50]);
                Screen('Flip', window_ptr);
                WaitSecs(timing.iti);
                underline(xPos, yPos, p.level, window_ptr);
                Screen('Flip', window_ptr);
                WaitSecs(timing.tdur);
            end
            break
        end
        while ~early_exit  
            timeout = false;
            for k = 1:p.level
                if GetSecs - ans_onset >= this_trial(2)
                    timeout = true;
                    break;
                end
                remaining_time = this_trial(2) - (GetSecs - ans_onset);
                [resp_code,timed_out, window_ptr] = Flashing_U( ...
                    xPos, yPos, ycenter, p.level, window_ptr, k, resp_list, remaining_time);
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
                    resp = valid_names(valid_codes == find(resp_code));
                    % resp1 = [resp1, resp];
                    corr = [corr, double(resp == correctAnswer(k))];
                    resp_list(k) = resp;
                end
                underline(xPos, yPos, p.level, window_ptr, k, resp_list)

            end
            if timeout
                rec.score(trial) = 0;
            else
                score = all(corr ~= 0);
                rec.score(trial) = score;
            end
            vbl = Screen('Flip', window_ptr);
            if vbl < trial_end
                WaitSecs(trial_end - vbl);
            end
            vbl = Screen('Flip', window_ptr);
            if isnan(onset_timestamp)
                onset_timestamp = vbl;
            end
            rec.offset_real(trial) = onset_timestamp - start;
            p.level = p.level + 1;
            break
        end
    end
        
catch exception
    status = -1;
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

function [keyCode,timed_out, window_ptr] = Flashing_U( ...
    xPos, yPos, ycenter, level, window_ptr, current, resp_list,remaining_time)
    keys = struct( ...
    'exit', KbName('Escape'));
    timed_out = false;

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
    while ~keyIsDown && GetSecs < end_time && ~early_exit
        [keyIsDown, ~, keyCode] = KbCheck;
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
        Screen('Flip', window_ptr);
        
        % Blinking every 0.5s
        if GetSecs - start_time >= 0.5
            visibility = ~visibility;
            start_time = GetSecs; % reset timer
        end     
    end

    if GetSecs >= end_time && ~keyIsDown
        timed_out = true;
    end
    KbReleaseWait
end