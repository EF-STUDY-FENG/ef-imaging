loc = randi(p.nSquare, p.nTrialPerBlock);
        yn = false(p.nTrialPerBlock-2, 1);
        yn(1:8) = true;
        yn = Shuffle(yn);
        yn = [false(2,1); yn]; %ok
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
            ok = strcmp(key, p.keys{1}) == yn(i);
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

        % instr = '休息一下\n按 1 键继续.';
        % DrawFormattedText(window_ptr, double(instr), 'center', 'center', WhiteIndex(window_ptr));
        % Screen('Flip', window_ptr);
        % KbReleaseWait; WaitTill(p.keys);
        
    % end
    accu=length(find(rec(:,4)==1))/((p.nTrialPerBlock-2)*p.nBlock);
