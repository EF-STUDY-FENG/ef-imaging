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
% subconfig{2} = 1;
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

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'));

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
        ignoreKey = keyCode;
        DisableKeysForKbCheck(ignoreKey);
    end

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
    funcSeq = {@numlet, @let3back, @stroop, @antisac, @colshp, ...
        @spt2back, @keeptrack, @sizelife, @stopsignal};

    for idx = 1:length(n)
        funcSeq{n(idx)}(run, subconfig, window_ptr, window_rect, outFolderPath);
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

%%% ---- Each Task Func ---- %%%
%% -- NumLet Task -- %%
function  numlet(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_numlet(run, window_ptr, window_rect, 1);
save_task_data('numlet', rec, subconfig, outFolderPath);
end

%% -- Let3Back Task -- %%
function  let3back(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_let3back(run, window_ptr, window_rect, 1);
save_task_data('let3back', rec, subconfig, outFolderPath);
end

%% -- Stroop Task -- %%
function  stroop(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_stroop(run, window_ptr, window_rect, 1);
save_task_data('stroop', rec, subconfig, outFolderPath);
end

%% -- AntiSac Task -- %%S
function  antisac(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_antisac(run, window_ptr, window_rect, 1);
save_task_data('antisac', rec, subconfig, outFolderPath);
end

%% -- ColShp Task -- %%
function  colshp(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_colshp(run, window_ptr, window_rect, 1);
save_task_data('colshp', rec, subconfig, outFolderPath);
end

%% -- Spt2Back Task -- %%
function  spt2back(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_spt2back(run, window_ptr, window_rect, 1);
save_task_data('spt2back', rec, subconfig, outFolderPath);
end

%% -- KeepTrack Task -- %%
function  keeptrack(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_keeptrack(run, window_ptr, window_rect, 1);
save_task_data('keeptrack', rec, subconfig, outFolderPath);
end

%% -- SizeLife Task -- %%
function  sizelife(run, subconfig, window_ptr, window_rect, outFolderPath)
rec = start_sizelife(run, window_ptr, window_rect, 1);
save_task_data('sizelife', rec, subconfig, outFolderPath);
end

%% -- Stop Signal Task -- %%
function  stopsignal(run, subconfig, window_ptr, window_rect, outFolderPath)
[rec, out_ssd] = start_stopsignal(run, window_ptr, window_rect, 1);
save_task_data('stopsignal', rec, subconfig, outFolderPath);
ssd_run = sprintf('sub%s_outssd.mat', subconfig{1});
out_ssd_place = fullfile(outFolderPath, ssd_run);
save(out_ssd_place, "out_ssd");
end



function save_task_data(task_name, rec, subconfig, outFolderPath)

% run = subconfig{2};
filename = sprintf('sub-%s_task-%s_test_events.tsv',...
    subconfig{1}, task_name);

writetable(rec, fullfile(outFolderPath, filename),...
    'FileType', 'text',...
    'Delimiter', '\t');
end
