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

clear all; clf; clc;

% Sevice UUID: '19b10000-e8f2-537e-4f6c-d104768a1214'
% Characteristic UUID: 'ca164c88-9eee-47a0-8c1f-f875f38d0351'

VITAL_DATA(1, 1:2) = [0, 0];
TOTAL_TIME = 0;

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

currentTime = 0;
currentIndex = 1;

totalTime = 0; % Overall
maxTime = 7; % Per cycle

allPlotPoints(1) = 0; % For the actal plot() elements
allPlotValues(1, 1:2) = [0, 0]; % for [currentTime, vitalValue]

firstLoopComplete = false; % Create or recycle plot points

xlabel("time (0 -> 7 seconds)"); ylabel("Vital"); title("Stethoscope");

function createOrModifyNewPlotPoint(deltaTime, vitalValue)

    currentTime = currentTime + deltaTime;
    totalTime = totalTime + deltaTime;

    if firstLoopComplete

        hold on;

        if currentIndex <= length(allPlotPoints)
            allPlotPoints(currentIndex).XData = currentTime;
            allPlotPoints(currentIndex).YData = vitalValue;
        else
            
            newPlotValue = plot(currentTime, vitalValue, 'rx');
            allPlotPoints(currentIndex) = newPlotValue;
            allPlotValues(currentIndex, 1:2) = [currentTime, vitalValue];
        end

        
    else
        hold on;
        newPlotValue = plot(currentTime, vitalValue, 'rx');
        allPlotPoints(currentIndex) = newPlotValue;
        allPlotValues(currentIndex, 1:2) = [currentTime, vitalValue];
    end

    currentIndex = currentIndex + 1;

    if currentTime >= maxTime
        if ~firstLoopComplete
            firstLoopComplete = true;
        end

        currentTime = 0;
        currentIndex = 0;
    end


end

% END
%{
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

c = characteristic(device, serviceUUID, charUUID);

write(c, startSendingVitalsByte);

c.DataAvailableFcn = @newVitalData;

function newVitalData(src, ~)
    rawData = read(src, 'oldest');

    payload = typecast(rawData(0:1), 'uint16');
    commandByte = typecast(rawData(2), 'uint8');
    timeDelta = typecast(rawData(3:4), 'uint16');
    VITAL_PAYLOAD = typecast(rawData(5:end), 'uint16');

    createOrModifyNewPlotPoint(timeDelta, VITAL_PAYLOAD);
end

%}
