%%% ---- Folder Config  ---- %%%
prompt = {'SubID:'};
dlgtitle = 'sub-config';
num_lines = 1;

subconfig = inputdlg(prompt,dlgtitle,num_lines);

outFolderName = 'TestResults';
outFolderPath = fullfile(pwd, outFolderName);
if ~exist(outFolderPath, 'dir') % Created Folder, if the folder does not exist
    mkdir(outFolderPath);
end

% % ---- configure exception ----
status = 0;
exception = [];
run = 1;

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% sync tests are recommended but may fail
old_sync = Screen('Preference', 'SkipSyncTests', 1);
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen));
% PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard config ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'allow', [KbName('1!'), KbName('2@'), KbName('3#'), KbName('4$')]);
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'));
% Solve stuck key issue
% Reset the disabled keys to ensure no keys are ignored before configuring ignored keys
DisableKeysForKbCheck([]);
[~, ~, keyCode] = KbCheck; % Removed unused variable 'keyIsDown'
keyCode = find(keyCode);
ignoreKeys = setdiff(keyCode, [keys.start, keys.exit, keys.allow]);
if ~isempty(ignoreKeys)
    DisableKeysForKbCheck(ignoreKeys);
end

% ---- seq config ---- %
config = readtable(fullfile("config/main_program", 'seq.xlsx'));
n = str2num(strjoin(config.run(run)));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % open a window and set its background color as black
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    [xcenter, ycenter] = RectCenter(window_rect);
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));

    % ---- start '+' display ---- %
    DrawFormattedText(window_ptr, '+', 'center', 'center', WhiteIndex(window_ptr));
    Screen('Flip', window_ptr);
    while ~early_exit
        % here we should detect for a key press and release
        [~, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            vbl = Screen('Flip',window_ptr);
            start = vbl;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % --- Main Program --- %
    funcSeq = {'numlet', 'let3back', 'stroop', 'antisac', 'colshp', ...
        'spt2back', 'keeptrack', 'sizelife', 'stopsignal'};

    for idx = 1:length(n)
        taskonset_timestamp = instPlayed(funcSeq{n(idx)}, window_ptr);
        rti = taskonset_timestamp - start; % Run and Task Interval
        generalFunc(funcSeq{n(idx)}, run, start, rti, subconfig, window_ptr, window_rect, outFolderPath, 1);
    end

    % ---- END Inst Display ---- %
    endtime = GetSecs;
    dur = endtime - start;
    Screen('Flip', window_ptr);
    DrawFormattedText(window_ptr, double('请闭眼等待'), 'center', 'center', WhiteIndex(window_ptr));
    Screen('Flip', window_ptr);   % show stim, return flip time
    WaitSecs(3);


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

%% ---- Call Each Task Function ---- %%
function generalFunc(taskName, run, start, rti, subconfig, window_ptr, window_rect, outFolderPath, prac)
funcName = ['start_', taskName];
try
    if strcmp(funcName, 'start_stopsignal')
        % Handle stopsignal task
        [rec, out_ssd] = taskpool.start_stopsignal(run, start, rti, window_ptr, window_rect, [], prac);
        ssd_run = sprintf('sub%s_outssd.mat', subconfig{1});
        out_ssd_place = fullfile(outFolderPath, ssd_run);
        save(out_ssd_place, "out_ssd");
    else
        % Call other tasks normally
        rec = taskpool.(funcName)(run, start, rti, window_ptr, window_rect);
    end
    save_task_data(funcName, rec, subconfig, outFolderPath);
catch ME
    fprintf('%s function call failed: %s\n', funcName, ME.message);
end
end

%% ---- Save Data Function ---- %%
function save_task_data(taskName, rec, subconfig, outFolderPath)

filename = sprintf('sub-%s_task-%s_prac_events.tsv',...
    subconfig{1}, taskName);

writetable(rec, fullfile(outFolderPath, filename),...
    'FileType', 'text',...
    'Delimiter', '\t');
end

%% ---- Inst Played Function ---- %%
function taskonset_timestamp = instPlayed(taskName, window_ptr)

Inst = imread(sprintf('Instruction\\%s.jpg', taskName));  %%% instruction
tex=Screen('MakeTexture', window_ptr, Inst);
Screen('DrawTexture', window_ptr, tex);
Screen('Flip', window_ptr);
WaitSecs(4.5);
vbl = Screen('Flip', window_ptr); % show inst, return flip time
if ~strcmp(taskName, 'spt2back')
    WaitSecs(0.5);
end
taskonset_timestamp = vbl + 0.5;
end
