%{
    Name: Jamal-Adam Qattan
    Prof: Ryan Petitfils
    Class: ENGR V14 - MATLAB For Engineers
    Project: Digital Stethoscope with Arduino
    Purpose: 
    
        To be able to take a persons heart rate, filter it via MATLAB
        and display on graphs in MATLAB
    How this will be possible:
        I will be using a PPG (Photoplethysmography) sensor, A sallen-key
        low pass filter (With adjustable resistances via potentiometers),
        and an Arduino. These will work together to gather vital data which
        will be processed in C++ to send over bluetooth low energy (BLE) to
        MATLAB via BLE protocols. By doing this, I can have the stethoscope
        on someone from across the room and MATLAB will still recieve the
        data. 
        On MATLAB's side, it will be recieving packages containing the
        following data:
            1) Number of bytes TOTAL for the data 
            2) A command byte (determining what the data means)
            3) The payload including vital data
        These values will be stored in a fixed-sized vector which will be
        filling up at the end, but releasing memory in the beginning of the
        vector so new values can join along. These will be plotted on
        several graphs for different purposes
        The first graph will be the NEW DATA we recieve in each payload.
        This will be a small section which may not mean much, but this is
        important so we know what we are recieving from Arduino
        The next graph will be the unfiltered signal from the Arduino and
        the COMPLETE VECTOR ARRAY. 
        The last graph will be the filtered and smooth signal that has
        smoother points and will have markings of where peaks occur,
        indicating peak blood vessel contractions. 
        Based on the graphs and the time deltas presented using
        tic/toc commands by MATLAB, MATLAB will be able to easily 
        identify the heart rate of the individual.
%}
%{
Have a starter vector array that contains all vital data
- This starter vector has a max value ranging from 0 to the end of x-axis
When we connect to the bluetooth device, send the 0x10 byte to begin
collecting and sending vital data (0x08) is to stop sending the data
Each time data is recieved, it will contain the following:
- First 2 bytes is payload in Little-Endian form
- Next 1 byte is command byte (almost always will be vital data)
- Next 2 bytes is time delta (important for BPM calculations)
- Next n bytes is full payload
%}
% Sevice UUID: '19b10000-e8f2-537e-4f6c-d104768a1214'
% Characteristic UUID: 'ca164c88-9eee-47a0-8c1f-f875f38d0351'
%{
When we add new plots to the graph, have a rectangle right in front of the
plots so it covers the next plot points like a real vital sign machine.
have the x value be equal to currentIndex times some constant (experimental)
Have a general vector array that fills but stays at a fixed size, going
back to the start value. This will require a currentIndex variable. If
currentIndex variable is then over a certain amount, then have it return
back to 1.
The vector above will be used to run DSP algorithms on.
%}
% Have time from left to right be 7 seconds
%{
FOR THE FIRST TIME GOING LEFT TO RIGHT:
Have plotting be regular and store each [value timestamp] in nx2 vector
and the currentIndex going up by one each time
Once we have reached the very right side, set the currentIndex back to 1
and clear (zero out) the first 10-20 points from the graph. SET A FLAG
VARIABLE DENOTING THE (have we cleared the very first time) TO TRUE!
From now and on, clear the plot point that is (10-20) + 1 points away from
the current index, but modulate this by the total number of points per
left-right iteration, so it can go back to the left side when needed
NEEDED VECTORS
have a nx1 vector of actual plotting elements so we can remove when needed
have a nx2 vector with vital data where [x, y] is [currentTime, vitalValue]
%}
% START

% Data struct is used as a large structure to store everything I need to
% make important calculations such as time required per x-axis sweep, or
% plot value matrix, and etc. The heartData Struct is then used to store
% important information that the application as a whole will need such as
% estimated BPM, number of beats counted currently and total, and elapsed
% time in order to perform the calculation.

clear; clc; clf;
dataStruct.smoothingFactor = 6; % Radius of smoothing
dataStruct.currentTime = 0;
dataStruct.totalTime = 0;
dataStruct.currentIndex = 0;
dataStruct.maxTime = 8000;
dataStruct.allPlotPoints = gobjects(1, 1000); % For the actal plot() elements
dataStruct.allPlotValues = zeros(4000, 2); % for [currentTime, vitalValue]
dataStruct.firstLoopComplete = false; % Create or recycle plot points

dataStruct.totalHeartBeats = 0;

dataStruct.sampleCount = 1;

xlabel("time (0 -> 7 seconds)"); ylabel("Vital"); title("Stethoscope");
hold on;
heartBeatData.initIndexOfHeartBeat = 0;
heartBeatData.finalIndexOfHeartBeat = 0;
heartBeatData.initTimeOfHeartBeat = 0;
heartBeatData.finalTimeOfHeartBeat = 0;
heartBeatData.currentVectorOfPulse(1, 1:2) = [0 0];
heartBeatData.timeToMaxVitalMatrix(1, 1:2) = [0 0]; % [timeOccured vitalValue] for plotting and determining BPM
heartBeatData.currentBPM = 0; % Use based off the last 3 timeToMaxVitalMatrix rows
heartBeatData.allBPM(1) = 0;
heartBeatData.currentlyStoringHeartBeat = false;
heartBeatData.restartedDuringActiveHeartBeat = false;

heartBeatData.BPM = 0;
heartBeatData.BPMFound = false;

heartBeatData.heartBeatsCounted = 0;
heartBeatData.heartBeatsCountedMax = 10;
heartBeatData.elapsedTimeForCount = 0;

heartBeatData.beatsInSegment = 0;


heartBeatData.allPeaks(1, 1:2) = [0 0];
%heartBeatData.allPeakIDX(1) = 1;

heartBeatData.smoothDataValues(1, 1:2) = [0 0];
heartBeatData.smoothDataPlots(1) = 0;

setappdata(0, 'heartdata', heartBeatData);

subplot(2, 1, 1); cla;
title("Raw Vital Monitor (No DSP)");
xlabel("time (m/s)");
ylabel("Vital Units");

ax1 = subplot(2, 1, 1);

dataStruct.hRaw = animatedline(ax1, 'Color', 'r', 'LineWidth', 1.2);

xlim([0 dataStruct.maxTime]);
ylim([200 800]);

%hold on;

subplot(2, 1, 2); cla;
title("Filtered Vital Monitor (With DSP)");
xlabel("time (m/s)");
ylabel("Vital Units (filtered)");

ax2 = subplot(2, 1, 2);

dataStruct.hSmooth = animatedline(ax2, 'Color', 'b', 'LineWidth', 1.5);
dataStruct.hPeaks  = animatedline(ax2, 'LineStyle', 'None', 'Marker', 'x', 'Color', 'r', 'LineWidth', 1.5);

dataStruct.smoothingInterval = 3000;
dataStruct.smoothingIntervalCounter = 0;

dataStruct.currentTimeIndex = 1;

xlim([0 dataStruct.maxTime]);
ylim([200 800]);

%hold on;

% END
startSendingVitalsByte = uint8(0x10);
stopSendingVitalsByte = uint8(0x08);
disp('Scanning for BLE devices...');
deviceList = blelist;
disp(deviceList);
device = ble("Heart Rate Monitor"); 
disp('Connected to Arduino!');
disp(device.Characteristics);
serviceUUID = "19b10000-e8f2-537e-4f6c-d104768a1214";
charUUID    = "ca164c88-9eee-47a0-8c1f-f875f38d0351";
setappdata(0, 'dataStruct', dataStruct);
c = characteristic(device, serviceUUID, charUUID);
c.DataAvailableFcn = @(src, event) newVitalData(src, event);
dataStruct.characteristic = c;
setappdata(0, 'dataStruct', dataStruct);

function newVitalData(src, ~)
    rawData = read(src, 'oldest')';
    %disp('Raw Data Bytes:');
    %disp(rawData');
    %write(src, uint8(0x05), "withoutresponse");

    % in the code below, I parse the bytes recieved by arduino and focus on
    % the 3 bytes recieved where one byte is the time delta in milliseconds
    % and the last 2 are the vital value. I did some simple arithmetic to
    % extract the value of the bytes by taking 256 times the greatest byte
    % and adding that with 1 times the least byte. Afterward, I then call
    % my callback function createOrModifyNewPlotPoint to get the fun
    % started with processing data and adjusting our global data structures
    % further.

    if length(rawData) >= 5
        payload = typecast(rawData(1:2, 1), 'uint16');
        commandByte = typecast(rawData(3, 1), 'uint8');
        timeDelta = typecast(rawData(4:5, 1), 'uint16');
        VITAL_PAYLOAD = typecast(rawData(6:7, 1), 'uint16');
        singlePay = VITAL_PAYLOAD(1);
        createOrModifyNewPlotPoint(rawData(4), (rawData(6) + (256 * rawData(7))));
    end
    
    
end
function createOrModifyNewPlotPoint(deltaTime, vitalValue) % Pass in deltaTime and vitalValue
    
    ds = getappdata(0, 'dataStruct');
    heartData = getappdata(0, 'heartdata');
    ds.currentIndex = ds.currentIndex + 1;

    % Before doing anything, I must addour cummulative time by the time
    % delta recieved by arduino, almost like how integration works in
    % calculus! I do this before doing ANYTHING ELSE! (aside from retriving
    % our global data values)
    
    ds.currentTime = ds.currentTime + deltaTime;

    heartData.elapsedTimeForCount = heartData.elapsedTimeForCount + deltaTime;

    ds.smoothingIntervalCounter = ds.smoothingIntervalCounter + deltaTime;

    ds.totalTime = ds.totalTime + deltaTime;
    
    % before the slope calculation attempts to read them.
    ds.allPlotValues(ds.currentIndex, 1:2) = [ds.currentTime, vitalValue];

    subplot(2, 1, 2);
    %hold on;
    xlim([0 ds.maxTime]); % DELETE (maybe)
    %ylim([0 1300]); % DELETE (maybe)

    NUM_OF_PEAKS = 0;

    NEW_BEAT_DETECTED = false;

    
    %HERE IS NEW CODE
    
    if isvalid(ds.hSmooth)
        addpoints(ds.hSmooth, ds.currentTime, vitalValue);
    end

    if ds.smoothingIntervalCounter >= ds.smoothingInterval

        if ds.currentIndex >= 5
            % Time to smooth!
            tVec = ds.allPlotValues(1:ds.currentIndex, 1);
            yVec = ds.allPlotValues(1:ds.currentIndex, 2);
    
            win = min(31, ds.currentIndex);

            [tUnique, ia] = unique(tVec, 'stable');

            [tSorted, ta] = sort(tUnique, "ascend");

            yVecSorted = yVec(ia(ta));

            win = min(win, length(yVecSorted));
            if mod(win, 2) == 0
                win = win - 1;
            end

            startIdx = min(max(1, ds.currentTimeIndex), length(yVecSorted));
            endIdx = length(yVecSorted);

            if length(yVecSorted) == length(tSorted) && (endIdx - startIdx + 1) >= 3
                if win >= 3
                    ySmooth = smoothdata(yVecSorted, "movmean", win, "SamplePoints", tSorted);

                    xSlice = tSorted(startIdx:endIdx);
                    ySlice = ySmooth(startIdx:endIdx);
                    xSpan = xSlice(end) - xSlice(1); % Getting time difference for peak distance min calculation in next line

                    if xSpan > 1
                        minPeakDist = min(400, xSpan * 0.8);
                        % In the above line, we are essentially specifying
                        % our peaks to be a certain distance and anything
                        % past that distance will be disconsidered. the 0.8
                        % was a value achieved through trial and error.
                        % Essentially, we are reducing the radius of our
                        % peak by 0.2 to get that 0.8.
                        [peaksBeats, locsBeats] = findpeaks(ySlice, xSlice, 'MinPeakProminence', 100, 'MinPeakDistance', minPeakDist);
                    else
                        peaksBeats = [];
                        locsBeats = [];
                    end

                    NUM_OF_PEAKS = numel(peaksBeats);

                    % We will count the number of peaks, then add this to
                    % our counter to then determine BPM.

                    heartData.heartBeatsCounted = heartData.heartBeatsCounted + NUM_OF_PEAKS;

                    if heartData.heartBeatsCounted >= heartData.heartBeatsCountedMax

                        % using dimensional anaylysis, I derived this
                        % formula to determine BPM based on how much time
                        % it takes heart to beat a fixed number of times.

                        estimatedBPM = (heartData.heartBeatsCounted / heartData.elapsedTimeForCount) * 60000;
                        
                        heartData.BPM = estimatedBPM;
                        heartData.BPMFound = true; % A flag for the next code block (based on if this variable is true)
            
                        fprintf("Your BPM is %.0f \n", estimatedBPM);
            
                        % Below, we reset our count and elapsed time back
                        % to initial to get more accurate readings after
            
                        heartData.heartBeatsCounted = 0;
                        heartData.elapsedTimeForCount = 0;
                    end

                    disp(NUM_OF_PEAKS + " peaks detected");

            
                    ds.totalHeartBeats = ds.totalHeartBeats + NUM_OF_PEAKS;

                    % Below is where we add "x"'s to our plot in order to
                    % locate peaks and see them!
                
                    addpoints(ds.hPeaks, locsBeats, peaksBeats);

                    % Below, I set the currentTimeIndex to be where our
                    % sampling data ends so in the next sample, we know
                    % where to start since each sample will include
                    % previous data in the same window.

                    % I did this because I don't want to recount the same
                    % heartbeats that were already counted in the previous
                    % smoothing calls

                    ds.currentTimeIndex = endIdx;
                else
                    ySmooth = smoothdata(yVecSorted, "movmean", win);
                end

                if isvalid(ds.hSmooth)
                    % We want to make sure ds.hSmooth is valid or exists
                    % before doing this just for safety since this caused
                    % me errors before.

                    % Just clear the smooth points in the smoothing frame
                    % and replace with the new smooth points
                    clearpoints(ds.hSmooth);
                    addpoints(ds.hSmooth, tSorted, ySmooth);
                end

            end

            if heartData.BPMFound
                subplot(2, 1, 2); 
                delete(findobj(gca, 'Type', 'Text'));

                % this entire block is simple. When we have a BPM that is
                % calculated from the previous code block, remove text and
                % replace it with new text that shows sampling rate, BPM,
                % total beats, and a personalized message when needed be
                % based on a conditional
                
                sampleRateText = sprintf("%.0f samples per second", (ds.currentIndex / ds.currentTime) * 1000);
                text(1500, 700, sampleRateText, "FontSize", 16, "Color", "r", "FontWeight", "bold");
                
                totalBeatsText = sprintf("Total Beats: %.0f", ds.totalHeartBeats);
                text(1500, 500, totalBeatsText, "FontSize", 16, "Color", "r", "FontWeight", "bold");
                
                BPMText = sprintf("Your BPM: %.0f", heartData.BPM);
                text(1500, 600, BPMText, "FontSize", 16, "Color", "r", "FontWeight", "bold");

                if heartData.BPM >= 110
                    text(3000, 700, "YOUR BPM IS HIGH", "FontSize", 16, "Color", "r", "FontWeight", "bold");
                elseif heartData.BPM <= 50
                    text(3000, 700, "YOUR BPM IS LOW", "FontSize", 16, "Color", "r", "FontWeight", "bold");
                end
                
                heartData.BPMFound = false;
            end
    
            ds.smoothingIntervalCounter = 0; % Set this back to 0 to go back to counting

        end
    end

    % We will always be plotting new raw values based directly on what is
    % recieved by arduino.

    addpoints(ds.hRaw, ds.currentTime, vitalValue);

    if ds.currentTime >= ds.maxTime
        if ~ds.firstLoopComplete
            ds.firstLoopComplete = true; % This used to be useful
        end
        
        % Time to smooth!
        tVec = ds.allPlotValues(1:ds.currentIndex, 1);
        yVec = ds.allPlotValues(1:ds.currentIndex, 2);

        % The above varibles will for sure be the same size since the same
        % indeces are specified and by chain reaction of being used over
        % and over again

        % I mentioned this in a video, but i state the number 31 here
        % because the win means the window in which a heartbeat occurs and
        % I want this to be small so the ripples afterward will be
        % disconsidered.

        win = min(31, ds.currentIndex);

        [tUnique, ia] = unique(tVec, 'stable');

        [tSorted, ta] = sort(tUnique, "ascend");

        % By doing sort and unique, I am able to cut out any duplicate
        % values and sort them in ascending order because the "findpeaks"
        % function does not take duplicates or non-organized data sets.
        % This was very confusing because the error messages did not
        % specify the line causing issues in MY code, but it was stating
        % issues within the parsing code which is out of my reach. I had to
        % do research on this and ask AI why I was even getting this issue
        % and it told me that I was recieving the issue from the
        % "findpeaks" function and that I needed to make sure I had the
        % values sorted and have duplicates all removed before proceeding.

        yVecSorted = yVec(ia(ta));

        win = min(win, length(yVecSorted));
        if mod(win, 2) == 0
            win = win - 1;
        end

        % In startIdx, I make sure that the first parameter of the min is
        % always greater tha 1 for safety without modifying the actual
        % variable if it is under 1. In general, the startIdx and endIdx is
        % based on the smoothing interval we want so we can smooth out and
        % determine the number of heart beats that occur in that interval
        % only and not in the entire sample, causing recounts and bad BPM
        % values.

        startIdx = min(max(1, ds.currentTimeIndex), length(yVecSorted));
        endIdx = length(yVecSorted);

        if length(yVecSorted) == length(tSorted) && (endIdx - startIdx + 1) >= 3 % Make sure lengths are equal, or errors will occur and spam our feed
            if win >= 3
                ySmooth = smoothdata(yVecSorted, "movmean", win, "SamplePoints", tSorted);

                xSlice = tSorted(startIdx:endIdx);
                ySlice = ySmooth(startIdx:endIdx);
                xSpan = xSlice(end) - xSlice(1);

                % I reuse the same algorithm from above down here since it
                % works and I became tired to the point of reusing what I
                % had above. Essentially xSlice and ySlice are the time and
                % vital slices that are based on the smoothing interval and
                % xSpan is the x-axis range we will be working with. I will
                % then multiply this by 0.8 which will help us determine
                % how wide a peak will be with a cap (clamping) at a value
                % of 400. At this point, our peak distances will become
                % more picky and once again, disconsider ripples.

                if xSpan > 1
                    minPeakDist = min(400, xSpan * 0.8);
                    % The peak prominnace I use here being 100 is purely
                    % based on trying difference values. When I used 50, it
                    % was not picky enough and when I used 200, it was
                    % getting no peak values so it was too picky. 100 was
                    % the sweet spot.
                    [peaksBeats, ~] = findpeaks(ySlice, xSlice, 'MinPeakProminence', 100, 'MinPeakDistance', minPeakDist);
                else
                    peaksBeats = [];
                end

                % Same as a couple of hundred lines ago where I determine
                % the number of peaks and add it to the count and deterine
                % if we surpassed the number of hearts required to perform
                % a calculation. Remember, if we go over by one or two,
                % thats fine. Just do the regular calcuation with the
                % elapsed time and everything, and it will work out
                % nicely.

                NUM_OF_PEAKS = numel(peaksBeats);
        
                disp(NUM_OF_PEAKS + " peaks detected");
        
                heartData.heartBeatsCounted = heartData.heartBeatsCounted + NUM_OF_PEAKS;
        
                ds.totalHeartBeats = ds.totalHeartBeats + NUM_OF_PEAKS;
            else
                ySmooth = smoothdata(yVecSorted, "movmean", win);
            end
        else
            % This was for debugging. This was never called which is good!
            % But sort of frustarting since it means this is not the reason
            % for my program not working :(
            disp("NOOOO HERE IS THE PROBLEM IN THE LAST SECTION");
        end

        ds.currentTimeIndex = 1;

        if heartData.heartBeatsCounted >= heartData.heartBeatsCountedMax

            estimatedBPM = (heartData.heartBeatsCounted / heartData.elapsedTimeForCount) * 60000;
            
            heartData.BPM = estimatedBPM;
            heartData.BPMFound = true;

            fprintf("Your BPM is %.0f \n", estimatedBPM);

        end

        

        % STOP

        % After finishing with the entire x axis and we go back, we must
        % clear our points, but this isnt nearly as bad as clearing
        % "plot" points rather than the "animatedline" plot LINES.

        if isvalid(ds.hSmooth)
            clearpoints(ds.hSmooth);
        end
        
        if isvalid(ds.hPeaks)
            clearpoints(ds.hPeaks);
        end

        if isvalid(ds.hRaw)
            clearpoints(ds.hRaw);
        end

        subplot(2, 1, 2);
                
        if heartData.BPMFound
            subplot(2, 1, 2); 
            delete(findobj(gca, 'Type', 'Text'));

            %{
            
                Below, I print out statements such as the sampling
                frequency from the arduino, estimated BPM, total beats, and
                a personalized message for the client if their BPM is too
                high or too low.
            
            %}
            
            sampleRateText = sprintf("%.0f samples per second", (ds.currentIndex / ds.currentTime) * 1000);
            text(1500, 700, sampleRateText, "FontSize", 16, "Color", "r", "FontWeight", "bold");
            
            totalBeatsText = sprintf("Total Beats: %.0f", ds.totalHeartBeats);
            text(1500, 500, totalBeatsText, "FontSize", 16, "Color", "r", "FontWeight", "bold");
            
            BPMText = sprintf("Your BPM: %.0f", heartData.BPM);
            text(1500, 600, BPMText, "FontSize", 16, "Color", "r", "FontWeight", "bold");

            if heartData.BPM >= 110
                text(3000, 700, "YOUR BPM IS HIGH", "FontSize", 16, "Color", "r", "FontWeight", "bold");
            elseif heartData.BPM <= 50
                text(3000, 700, "YOUR BPM IS LOW", "FontSize", 16, "Color", "r", "FontWeight", "bold");
            end
            
            heartData.BPMFound = false;

            heartData.heartBeatsCounted = 1;
            heartData.elapsedTimeForCount = 0;
        end

        % Below, I set index back to 0 and time back to 0 so our x-axis can
        % go back to 0 properly.

        ds.currentIndex = 0;
        ds.currentTime = 0;
        
    end

    % Set the global app data! This is so we make sure our global data
    % actually changes and that we werent just messing with a copy the
    % whole time (reference vs copy in c++)

    setappdata(0, 'dataStruct', ds);
    setappdata(0, 'heartdata', heartData);

    drawnow limitrate

    % We must use drawnow limitrate because it will simply render at a
    % specific rate and I do this once every 70 frames (which is about one
    % time a second) and it great for animation and making the line
    % rendering very smooth. I had to research for this because I spent
    % days working on this bug in particular and wondering why it was
    % running slow desepite using "animatedline" objects.

    if mod(ds.currentIndex, 70) == 0
        drawnow limitrate;
    end

end
