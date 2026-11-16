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
function newVitalData(src, ~)
    rawData = read(src, 'oldest')';
    disp('Raw Data Bytes:');
    disp(rawData');
    %write(src, uint8(0x05), "withoutresponse");
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

    disp([deltaTime, vitalValue]);

    ds.currentIndex = ds.currentIndex + 1;
    ds.currentTime = ds.currentTime + deltaTime;

    fprintf("Time elapsed: %d milliseconds", ds.currentTime);

    ds.totalTime = ds.totalTime + deltaTime;
    if ds.firstLoopComplete
        hold on;
        if ds.currentIndex <= length(ds.allPlotPoints)
            ds.allPlotPoints(ds.currentIndex).XData = ds.currentTime;
            ds.allPlotPoints(ds.currentIndex).YData = vitalValue;

            %{
            for l = 1:20
                

                if ds.allPlotPoints(ds.currentIndex + l).XData >= ds.allPlotPoints(ds.currentIndex).XData & ~isempty(ds.allPlotPoints(ds.currentIndex + l)) & isvalid(ds.allPlotPoints(ds.currentIndex + l))
                    ds.allPlotPoints(ds.currentIndex + l).YData = 0;
                end

            end

            %}

            starterIndexAdder = 1;

            while ds.allPlotPoints(mod((ds.currentIndex + starterIndexAdder), length(ds.allPlotPoints))).XData + 150 < ds.allPlotPoints(ds.currentIndex).XData & ~isempty(ds.allPlotPoints(ds.currentIndex + starterIndexAdder)) & isvalid(ds.allPlotPoints(ds.currentIndex + starterIndexAdder))
                ds.allPlotPoints(ds.currentIndex + starterIndexAdder).YData = 0;
                starterIndexAdder = starterIndexAdder + 1;
            end

            ds.allPlotValues(ds.currentIndex, 1:2) = [ds.currentTime, vitalValue];
        else
            
            
            ds.allPlotPoints(ds.currentIndex) = plot(ds.currentTime, vitalValue, 'rx');
            ds.allPlotValues(ds.currentIndex, 1:2) = [ds.currentTime, vitalValue];
        end
        
    else
        hold on;
        %disp(size(initStruct.currentTime));
        %disp(vitalValue);
        %disp([ds.currentIndex, ds.currentTime, deltaTime]);
        ds.allPlotPoints(ds.currentIndex) = plot(ds.currentTime, vitalValue, 'rx');
        ds.allPlotValues(ds.currentIndex, 1:2) = [ds.currentTime, vitalValue];
    end
    
    if ds.currentTime >= ds.maxTime
        if ~ds.firstLoopComplete
            ds.firstLoopComplete = true;
        end
        ds.currentTime = 0;
        disp(ds.currentTime);
        ds.currentIndex = 0;
    end

    

    setappdata(0, 'dataStruct', ds);
end


clear all; clc; clf;
dataStruct.currentTime = 0;
dataStruct.totalTime = 0;
dataStruct.currentIndex = 0;
dataStruct.maxTime = 3000;
dataStruct.allPlotPoints = gobjects(1, 1000); % For the actal plot() elements
dataStruct.allPlotValues(1, 1:2) = [0, 0]; % for [currentTime, vitalValue]
dataStruct.firstLoopComplete = false; % Create or recycle plot points
xlabel("time (0 -> 7 seconds)"); ylabel("Vital"); title("Stethoscope");
xlim([0 dataStruct.maxTime]);
ylim([100 350]);
hold on;


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

