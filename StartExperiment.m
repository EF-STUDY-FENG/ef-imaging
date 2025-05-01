%%% ---- Folder Config  ---- %%%
prompt = {'SubID:', 'Run:'};
dlgtitle = 'sub-config';
num_lines = 1;
% Check whether there are saved parameters
if evalin('base', 'exist(''savedParams'', ''var'')')
    savedParams = evalin('base', 'savedParams');
    definput = [savedParams(1), {''}];
else
    % For the first run, all parameters are set to empty by default
    definput = {'', ''};
end
subconfig = inputdlg(prompt,dlgtitle, num_lines, definput);

% If it is the first run, save the first three parameters to the base workspace
if ~evalin('base', 'exist(''savedParams'', ''var'')')
    assignin('base', 'savedParams', subconfig(1));
end

outFolderName = 'Results';
outFolderPath = fullfile(pwd, outFolderName);
if ~exist(outFolderPath, 'dir') % Created Folder, if the folder does not exist
    mkdir(outFolderPath);
end

% % ---- configure exception ----
status = 0;
exception = [];
run = str2double(subconfig{2});

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

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'allow', [KbName('1!'), KbName('2@'), KbName('3#'), KbName('4$')]);

% ---- seq config ----
config = readtable(fullfile("config/main_program", 'seq.xlsx'));
n = str2num(strjoin(config.run(run)));

%%
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

    % Solve Bug
    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown
        if ~ismember(keyCode, [keys.start, keys.exit, keys.allow])
            ignoreKey = keyCode;
            DisableKeysForKbCheck(ignoreKey);
        end        
    end

    while ~early_exit
        % here we should detect for a key press and release
        [~, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            vbl = Screen('Flip',window_ptr);
            start_timestamp = vbl;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % --- Main Program --- %
    funcSeq = {'numlet', 'let3back', 'stroop', 'antisac', 'colshp', ...
        'spt2back', 'keeptrack', 'sizelife', 'stopsignal'};
    run_start = 0;
    for idx = 1:length(n)
        [run_start, taskonset_timestamp] = instPlayed(funcSeq{n(idx)}, start_timestamp, window_ptr, run_start);
        rti = taskonset_timestamp - start_timestamp; % Run and Task Interval
        generalFunc(funcSeq{n(idx)}, run, start_timestamp, rti, subconfig, window_ptr, window_rect, outFolderPath);
    end

    % ---- END Inst Display ---- %
    endtime = GetSecs;
    dur = endtime - start_timestamp;
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
function generalFunc(taskName, run, start, rti, subconfig, window_ptr, window_rect, outFolderPath)
funcName = ['start_', taskName];
try
    if strcmp(funcName, 'start_stopsignal')
        % Handle stopsignal task
        if run == 1
            [rec, out_ssd] = taskpool.start_stopsignal(run, start, rti, window_ptr, window_rect, []);
            % save ssd to next run
            out_ssd_folder = sprintf('Results/%s_ssd/Sub%s', taskName, subconfig{1});
            if ~exist(out_ssd_folder, 'dir')
                mkdir(fullfile(pwd, out_ssd_folder));
            end
            ssd_run = sprintf('run%d.mat', run);
            out_ssd_place = fullfile(out_ssd_folder, ssd_run);
            save(out_ssd_place, "out_ssd");
        else
            init_ssd_place = sprintf('Results/%s_ssd/Sub%s/run%d.mat',taskName, subconfig{1}, run-1);
            load(init_ssd_place, "out_ssd"); % load the previous saved ssd
            init_ssd = out_ssd;
            [rec, out_ssd] = taskpool.start_stopsignal(run, start, rti, window_ptr, window_rect, init_ssd);
            out_ssd_place = sprintf('Results/%s_ssd/Sub%s/run%d.mat',taskName, subconfig{1}, run);
            save(out_ssd_place, "out_ssd");
        end
    else
        % Call other tasks normally
        rec = taskpool.(funcName)(run, start, rti, window_ptr, window_rect);
    end
    save_task_data(taskName, rec, subconfig, outFolderPath);
catch ME
    fprintf('%s function call failed: %s\n', funcName, ME.message);
end
end

%% ---- Save Data Function ---- %%
function save_task_data(taskName, rec, subconfig, outFolderPath)

run = subconfig{2};
filename = sprintf('sub-%s_task-%s_run-%s_events.tsv',...
    subconfig{1}, taskName, run);

writetable(rec, fullfile(outFolderPath, filename),...
    'FileType', 'text',...
    'Delimiter', '\t');
end

%% ---- Inst Played Function ---- %%
function [run_start, taskonset_timestamp] = instPlayed(taskName, start, window_ptr, run_start)
Instoffset_timestamp = run_start + 4.5 + start; % define inst display time
taskonset_timestamp = Instoffset_timestamp + 0.5; % define taskonset timestamp
Inst = imread(sprintf('Instruction\\%s.jpg', taskName));  %%% instruction
tex=Screen('MakeTexture', window_ptr, Inst);
Screen('DrawTexture', window_ptr, tex);
Screen('Flip', window_ptr); % show inst
Screen('Flip', window_ptr, Instoffset_timestamp);
if ~strcmp(taskName, 'spt2back')
    Screen('Flip', window_ptr, taskonset_timestamp);
else
    taskonset_timestamp = Instoffset_timestamp;
end
if strcmp(taskName, 'keeptrack')
    run_start = run_start + 79; % keeptrack task lasts for 74s + 5s(inst display)
else
    run_start = run_start + 65; % Each task lasts for 60s + 5s(inst display)
end
end
