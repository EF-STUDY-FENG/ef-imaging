% 实验参数设置
excelFile = 'life_size.xlsx';    % Excel文件名
imageFolder = 'MateCateSwitch';       % 图片文件夹
nTrials = 10;                        % 总试次数
displayTime = 2;                      % 图片显示时间（秒）
verticalOffset = 200;                 % 上下图片垂直间距（像素）

% 读取Excel数据
[~, ~, raw] = xlsread(excelFile);
data = struct();
for i = 1:size(raw,1)
    data(i).image2 = raw{i,2};        % 第二列图片名
    data(i).image3 = raw{i,3};        % 第三列图片名
end

% 初始化Psychtoolbox
PsychDefaultSetup(2);
screenNumber = max(Screen('Screens'));
[win, winRect] = PsychImaging('OpenWindow', screenNumber, 0.5);
Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
HideCursor;

% 获取屏幕中心坐标
[screenX, screenY] = RectCenter(winRect);

try
    % 遍历所有试次
    for trial = 1:nTrials
        % 获取当前试次的图片信息
        centerImg = fullfile(imageFolder, data(trial).image2);
        topImg = fullfile(imageFolder, data(trial).image3);
        
        % 加载图片
        centerImage = imread(centerImg);
        topImage = imread(topImg);
        
        % 创建纹理
        centerTexture = Screen('MakeTexture', win, centerImage);
        topTexture = Screen('MakeTexture', win, topImage);
        
        % 计算显示位置
        % 中心图片位置
        [cH, cW, ~] = size(centerImage);
        centerRect = CenterRectOnPointd([0 0 cW cH], screenX, screenY);
        
        % 上方图片位置
        [tH, tW, ~] = size(topImage);
        topRect = CenterRectOnPointd([0 0 tW tH], screenX, screenY - verticalOffset);
        
        % 绘制图片
        Screen('DrawTexture', win, centerTexture, [], centerRect);
        Screen('DrawTexture', win, topTexture, [], topRect);
        
        % 翻转屏幕显示
        Screen('Flip', win);
        
        % 等待显示时间
        WaitSecs(displayTime);
        
        % 清空屏幕
        Screen('Flip', win);
        
        % 释放纹理内存
        Screen('Close', [centerTexture topTexture]);
    end
    
    % 结束实验
    ShowCursor;
    sca;
    
catch ME
    % 异常处理
    ShowCursor;
    sca;
    rethrow(ME);
end
