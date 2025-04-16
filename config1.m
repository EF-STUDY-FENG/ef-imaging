config = readtable(fullfile("AntiSac_config", "AntiSac_run5.xlsx"));
rec = config;
rec.onset = nan(height(config), 1);
for i = 2:height(config)
    rec.onset(i) = 0 + rec.Fixation_Dur(i-1) + 1.325 + rec.onset(i-1);
end
save AntiSac_run.xlsx rec
% 定义可选数值
values = [0.5, 0.75, 1, 1.25, 1.5];

% 随机生成互补对的数量
max_pairs = 14; % 最大互补对数（每对占2个元素）
a = randi([0, max_pairs]);        % 0.5和1.5的对数
remaining_pairs = max_pairs - a;
b = randi([0, remaining_pairs]);  % 0.75和1.25的对数

% 计算剩余位置填充1的数量
c = 28 - 2*a - 2*b;

% 生成数组
data = [
    0.5  * ones(a, 1);   % a个0.5
    1.5  * ones(a, 1);   % a个1.5
    0.75 * ones(b, 1);   % b个0.75
    1.25 * ones(b, 1);   % b个1.25
    ones(c, 1)           % 剩余为1
];

% 打乱顺序
data = data(randperm(28));

rec.cresp = string(height(config),1);
for i = 1:height(config)
    if rec.Tar_Dir(i) == 1
        rec.cresp(i) = "left";
    elseif rec.Tar_Dir(i) == 2
        rec.cresp(i) = "up";
    elseif rec.Tar_Dir(i) == 3
        rec.cresp(i) = "down";
    elseif rec.Tar_Dir(i) == 4
        rec.cresp(i) = "right";
    end
end

