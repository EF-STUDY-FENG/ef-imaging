%%% --- Main Program prac --- %%%
 %%% ---- Folder Config ---- %%%
prompt = {'SubID:', 'Sex:', 'Name:'};
dlgtitle = 'sub-config-prac';
num_lines = 1;
subconfig = inputdlg(prompt,dlgtitle,num_lines);

mainFolderName = sprintf('TestResults/Sub%s_%s_%s', subconfig{1}, subconfig{2}, subconfig{3});
mainFolderPath = fullfile(pwd, mainFolderName);
if ~exist(mainFolderPath, 'dir') % Created Folder, if the folder does not exist
    mkdir(mainFolderPath);
end

run = 1;

% % ---- configure exception ----
status = 0;
exception = [];

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
    % get inter flip interval
    % ifi = Screen('GetFlipInterval', window_ptr);
    %
    % % ---- configure stimuli ----
    % ratio_size = 0.3;
    % stim_window = [0, 0, RectWidth(window_rect), ratio_size * RectHeight(window_rect)];

    % ---- '+' display ---- %
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
            Screen('Flip',window_ptr);
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    %%% ---- Each Task Func ---- %%%
        %% -- NumLet Task -- %%
        [accu, rec] = start_numlet(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%03d_%s_%s_run%d_NumLet_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- Let3Back Task -- %%
        [accu, rec] = start_let3back(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_Let3Back_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- Stroop Task -- %%
        [accu, rec] = start_stroop(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_Stroop_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- antisac Task -- %%
        [accu, rec] = start_antisac(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_antisac_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- ColShp Task -- %%
        [accu, rec] = start_colshp(window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_ColShp_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- Spt2Back Task -- %%
        [accu, rec] = start_spt2back(window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_Spt2Back_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- KeepTrack Task -- %%
        [accu, rec, dur] = start_keeptrack(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_KeepTrack_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec", "dur");

        %% -- SizeLife Task -- %%
        [accu, rec] = start_sizelife(run, window_ptr, window_rect, 1);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_Cate_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        save(output_name, "accu", "rec");

        %% -- Stop Signal Task -- %%
        % if run == 1
        [accu, rec, out_ssd] = start_stopsignal(run, window_ptr, window_rect);
        T=char(datetime("now","Format","MM-dd_HH.mm"));
        TaskFile_name = sprintf('Sub%s_%s_%s_run%d_SST_%s.mat', subconfig{1}, subconfig{2}, subconfig{3}, run, T);
        output_name = fullfile(mainFolderPath, TaskFile_name);
        % out_ssd_place = sprintf('SST_config/Sub_ssd/Sub%03d_run%d_SST.mat', subconfig{1}, run);
        save(output_name, "accu", "rec", "out_ssd");
        % save(out_ssd_place, "out_ssd");
        % else
        %     init_ssd_place = sprintf('SST_config/Sub_ssd/Sub%03d_run%d_SST.mat', subID, run-1);
        %     load(init_ssd_place, "out_ssd");
        %     init_ssd = out_ssd;
        %     [accu, rec, out_ssd] = start_stopsignal(run, window_ptr, window_rect, init_ssd);
        %     T=char(datetime("now","Format","MM-dd_HH.mm"));
        %     TaskFile_name = sprintf('Sub%03d_%s_%s_run%d_SST_%s.mat', subID, sex, name, run, T);
        %     output_name = fullfile(runFolderPath, TaskFile_name);
        %     out_ssd_place = sprintf('SST_config/Sub_ssd/Sub%03d_run%d_SST.mat', subID, run);
        %     save(output_name, "accu", "rec", "out_ssd");
        %     save(out_ssd_place, "out_ssd");
        % end

        %% ---- END Inst Display ---- %%
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
