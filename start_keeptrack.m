function [accu, rec, status, exception] = start_keeptrack(opts)
arguments
    opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
end

    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        ignoreKey=keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end
% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
p.maxTri = 20;
p.level = 3;
Errors = 0;
rec = table();
rec.score = nan(p.maxTri, 1);
timing = struct( ...
    'iti', 1.0, ... % inter-trial-interval
    'tdur', 0.5); % trial duration

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
    'num1', KbName('1!'), ...
    'num2', KbName('2@'), ...
    'num3', KbName('3#'), ...
    'num4', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % open a window and set its background color as black
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    [xcenter, ycenter] = RectCenter(window_rect);
    screenWidth = window_rect(3);
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));


    % display welcome/instr screen and wait for a press of 's' to start
    instr = '按S键开始';
    DrawFormattedText(window_ptr, double(instr), 'center', 'center', WhiteIndex(window_ptr));
    Screen('Flip', window_ptr);
    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        ignoreKey=keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end
    while ~early_exit
        % here we should detect for a key press and release
        [~, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            % start_time = resp_timestamp;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % main experiment
    for trial = 1:p.maxTri
        if early_exit
            break
        end

        % initialize responses
        corr = [];
        % resp1 = []; 

        % Generate numeric sequence
        positions = cell(1, p.level);
        correctAnswer = zeros(1, p.level);

        event.pos = nan(0,1);
        event.digit = nan(0,1);
    
        for i = 1:p.level
            n = randi([1,3]);
            seq = randi([1 4], 1, n);
            positions{i} = seq;
            % correctAnswer(i) = seq(end); 
            for num = 1:n
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
            if p.level <= 6
                xPos = linspace(screenWidth*0.3, screenWidth*0.7, p.level);
                yPos = ones(1, p.level) * ycenter;
            elseif p.level == 7
                xPos = [linspace(screenWidth*0.3, screenWidth*0.7, 6),...
                        xcenter];
                yPos = [ones(1,6)*(ycenter-100),...  
                        ones(1,p.level-6)*(ycenter+100)];
            else
                xPos = [linspace(screenWidth*0.3, screenWidth*0.7, 6),...
                        linspace(screenWidth*0.3, screenWidth*0.7, p.level-6)];
                yPos = [ones(1,6)*(ycenter-100),...  
                        ones(1,p.level-6)*(ycenter+100)];
            end
            
            
                
            for j = randOrder
                [~, ~, key_code] = KbCheck(-1);
                if key_code(keys.exit)
                    early_exit = true;
                end
                if early_exit
                    break
                end
                i = event.pos(j);     % 当前事件所属的位置
                digit = event.digit(j); % 当前事件的数字
                correctAnswer(i) = digit;
                Screen('FillRect', window_ptr, 0);
                %draw underline
                underline(xPos, yPos, p.level, window_ptr);
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
            for k = 1:p.level
                instr_1 = sprintf('请输入位置 %d 的数字', k);
                underline(xPos, yPos, p.level, window_ptr);
                DrawFormattedText(window_ptr, double(instr_1),...
                       'center', ycenter-100, WhiteIndex(window_ptr));
                Screen('Flip', window_ptr);
                [~, key_code] = KbStrokeWait(-1);
                if key_code(keys.exit)
                    early_exit = true;
                    break
                else
                    resp_code = key_code;
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
                end


            end
            
            score = all(corr(:) ~= 0);
            rec.score(trial) = score;
            if score
                p.level = p.level + 1;
                Errors = 0;
            else
                Errors = Errors + 1;
                if Errors >= 2
                    p.level = p.level - 1;
                    Errors = 0;
                end
            end
            break
        end
    end
    accu = sum(rec{:, 1} == 1) / p.maxTri;

        

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

function underline(xPos, yPos, level, window_ptr)

    exampleNum = '0';  % 用于计算字符尺寸的示例数字
    bounds = Screen('TextBounds', window_ptr, exampleNum);
    textWidth = bounds(3);
    textHeight = bounds(4);
    underlinePadding = 5;  % 下划线与数字间距
    lineWidth = 5;         % 下划线粗细
    underlinesSingle = zeros(level,4);
    for i = 1:level
        underlinesSingle(i,:) = [xPos(i)-textWidth/2, yPos(i)+textHeight/2+underlinePadding,...
                                 xPos(i)+textWidth/2, yPos(i)+textHeight/2+underlinePadding];
    end

    for j = 1:level
        Screen('DrawLine', window_ptr, WhiteIndex(window_ptr),...
            underlinesSingle(j,1), underlinesSingle(j,2),...
            underlinesSingle(j,3), underlinesSingle(j,4),...
            lineWidth);
    end
end
