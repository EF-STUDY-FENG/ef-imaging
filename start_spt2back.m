function [accu, rec, status, exception] = start_spt2back(opts)
arguments
    opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
end

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
p.back = 127;
p.nBlock = 1;
p.nback = 2;
p.nSquare = 10;
p.squareSize = 54; % pixels, ~1.59 cm for 19-in monitor, 1280x1024
p.nTrialPerBlock = 24;
nTrial = p.nTrialPerBlock * p.nBlock;
p.recLabel = {'iBlock','iTrial' 'flashLoc' 'respCorrect' 'RT'};
rec = nan(nTrial, length(p.recLabel));
rec(:, 1) = 1:nTrial;
rec(:, 2) = kron(1:p.nBlock,ones(1,p.nTrialPerBlock));

% rec = [];
% rec.onset_real = nan(p.nTrialPerBlock, 1);
% rec.resp_raw = cell(p.nTrialPerBlock, 1);
% rec.resp = cell(p.nTrialPerBlock, 1);
% rec.rt = nan(p.nTrialPerBlock, 1);
timing = struct( ...
    'iti', 1.5, ... % inter-trial-interval
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
p.keys = {'1', '4'};
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'N', KbName('1!'), ...
    'Y', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % open a window and set its background color as black
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    %[xcenter, ycenter] = RectCenter(window_rect);
    % 25 grid with some random variation
    [x, y] = meshgrid((0:4) * p.squareSize * 2);
    x = x + window_rect(3)/2 + rand(5)*p.squareSize - p.squareSize*5;
    y = y + window_rect(4)/2 + rand(5)*p.squareSize - p.squareSize*5;
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));
    % get inter flip interval
    %ifi = Screen('GetFlipInterval', window_ptr);

    % ---- configure stimuli ----
    %ratio_size = 0.3;
    % stim_window = [0, 0, RectWidth(window_rect), ratio_size * RectHeight(window_rect)];

    % display welcome/instr screen and wait for a press of 's' to start
    sq=imread('sp2back_config\InstructionWM2.jpg','jpg');  %%% instruction 
    tex=Screen('MakeTexture',window_ptr,sq);
    Screen('DrawTexture',window_ptr,tex);
    Screen('Flip',window_ptr);   % show stim, return flip time

    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        ignoreKey=keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end

    while ~early_exit
        % here we should detect for a key press and release
        [resp_timestamp, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            start_time = resp_timestamp;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % main experiment
    for block = 1:p.nBlock
        if early_exit
            break
        end

        loc = randi(p.nSquare, p.nTrialPerBlock);
        yn = false(p.nTrialPerBlock-2, 1);
        yn(1:6) = true;
        yn = Shuffle(yn);
        yn = [false(2,1); yn]; %#ok
        while loc(2)==loc(1) % make the 2nd different from the 1st
            loc(2) = randsample(p.nSquare, 1);
        end
        for i = p.nback+1 : p.nTrialPerBlock
            if yn(i)
                loc(i) = loc(i-p.nback);
            else
                while any(loc(i) == loc(i-[1 p.nback]))
                loc(i) = randsample(p.nSquare, 1);
                end
            end
        end

        str = '下面是正式实验\n不会给你反馈';
        DrawFormattedText(window_ptr, double(str), 'center', 'center', WhiteIndex(window_ptr));
        Screen('Flip', window_ptr);
        pause(2);

        ind = randsample(25, p.nSquare);
        rects = [x(ind) y(ind) x(ind)+p.squareSize y(ind)+p.squareSize]';
        Screen('FrameRect', window_ptr, 255, rects, 3);
        %KbReleaseWait; WaitTill(p.keys);
        vbl = Screen('Flip', window_ptr);

        for i = 1:p.nTrialPerBlock
            tStart = vbl + timing.iti;
            Screen('FrameRect', window_ptr, 255, rects, 3);
            Screen('FillRect', window_ptr, 128, rects(:,loc(i))');
            WaitTill(tStart-0.02);
            t0 = Screen('Flip', window_ptr, tStart); % flash on
            [key, t] = WaitTill(p.keys, t0+timing.tdur);
            Screen('FrameRect', window_ptr, 255, rects, 3);
            Screen('Flip', window_ptr); % flash off

            if isempty(key)
                [key, t] = WaitTill(p.keys, t0+timing.tdur+timing.iti-0.1); 
            end
            if iscellstr(key), key = key{end}; end % multipe response
            vbl = t;
            ok = strcmp(key, p.keys{2}) == yn(i);
            if i<3 
                ok=NaN;t(1)=NaN;end

            iTrial = i + (block-1)*p.nTrialPerBlock;

            if isempty(key) % missed response
                rec(iTrial, 3) = loc(i);
            else    
                rec(iTrial, 3:5) = [loc(i) ok t(1)-t0]; % record stim & resp
            end
            rec(iTrial,6) = t0-start_time;
        end

        accu=length(find(rec(:,4)==1 & rec(:,2)==block))/(p.nTrialPerBlock-2);
        % disp(accu);
        % disp(rec);
        str = '休息一下\n按键继续.';
        DrawFormattedText(window_ptr, double(str), 'center', 'center', WhiteIndex(window_ptr));
        Screen('Flip', window_ptr);
        KbReleaseWait; WaitTill(p.keys);

    end


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