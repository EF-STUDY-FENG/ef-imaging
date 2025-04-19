function [accu, rec, dur, status, exception] = start_keeptrack(run, window_ptr, window_rect, prac)
% arguments
%     opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
% end
    % [keyIsDown, ~, keyCode] = KbCheck;
    % keyCode = find(keyCode, 1);
    % if keyIsDown
    %     ignoreKey=keyCode;
    %     DisableKeysForKbCheck(ignoreKey);
    % end
% ---- configure exception ----
status = 0;
exception = [];
accu = 0.00;
% ---- configure sequence ----
p.maxTri = 4;
p.level = 4;
p.offset = 85;
% Errors = 0;
config = readtable(fullfile("config/keeptrack_config", 'keeptrack.xlsx'));
rec = table();
rec.level = config.level;
if nargin > 3 && prac == 1
    rec.run = eval(sprintf('config.prac'));
else
    rec.run = eval(sprintf('config.run%d',run));
end
rec.score = nan(p.maxTri, 1);
timing = struct( ...
    'iti', 1.0, ... % inter-trial-interval
    'tdur', 0.5); % trial duration

% % ---- configure screen and window ----
% % setup default level of 2
% PsychDefaultSetup(2);
% % screen selection
% screen = max(Screen('Screens'));
% % set the start up screen to black
% old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% % sync tests are recommended but may fail
% old_sync = Screen('Preference', 'SkipSyncTests', 1);
% % use FTGL text plugin
% old_text_render = Screen('Preference', 'TextRenderer', 1);
% % set priority to the top
% old_pri = Priority(MaxPriority(screen));
% % PsychDebugWindowConfiguration([], 0.1);

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
    % [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    [~, ycenter] = RectCenter(window_rect);
    screenWidth = window_rect(3);
    % % disable character input and hide mouse cursor
    % ListenChar(2);
    % HideCursor;
    % % set blending function
    % Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % 
    % % set default font name
    % Screen('TextFont', window_ptr, 'SimHei');
    % Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));


    % display welcome/instr screen and wait for a press of 's' to start
    Inst = imread('Instruction\keeptrack.jpg');
    tex = Screen('MakeTexture',window_ptr, Inst);
    Screen('DrawTexture', window_ptr, tex);
    Screen('Flip',window_ptr); 
    WaitSecs(4.5);
    vbl = Screen('Flip',window_ptr); 
    WaitSecs(0.5);
    start = vbl + 0.5;

    % [keyIsDown, ~, keyCode] = KbCheck;
    % keyCode = find(keyCode, 1);
    % if keyIsDown
    %     ignoreKey=keyCode;
    %     DisableKeysForKbCheck(ignoreKey);
    % end
    % while ~early_exit
    %     % here we should detect for a key press and release
    %     [~, key_code] = KbStrokeWait(-1);
    %     if key_code(keys.start)
    %         % start_time = resp_timestamp;
    %         WaitSecs(5);
    %         break
    %     elseif key_code(keys.exit)
    %         early_exit = true;
    %     end
    % end

    % main experiment
    for trial = 1:p.maxTri
        if early_exit
            break
        end

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
            if p.level <= 7
                xPos = linspace(screenWidth*0.3, screenWidth*0.7, p.level);
                yPos = ones(1, p.level) * ycenter;
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
            for k = 1:p.level
                [resp_code, window_ptr] = Flashing_U(xPos, yPos, ycenter, p.level, window_ptr, k, resp_list);
                if resp_code(keys.exit)
                    early_exit = true;
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
            
            score = all(corr(:) ~= 0);
            rec.score(trial) = score;
            p.level = p.level + 1;

            break
        end
    end
    accu = sum(rec{:, 3} == 1) / p.maxTri;
    Endtime = GetSecs;
    dur = Endtime - start;
        

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

function [keyCode, window_ptr] = Flashing_U(xPos, yPos, ycenter, level, window_ptr, current, resp_list)
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
    visibility = true;
    keyIsDown = false;
    early_exit = false;
    while ~keyIsDown && ~early_exit
        [keyIsDown, ~, keyCode] = KbCheck;

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
    KbReleaseWait
end