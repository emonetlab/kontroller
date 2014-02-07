function [] = MinimiseAirspeedDifferences2(OptimiseThese,PulseDuration)
% MinimiseAirspeedDifferences.m
% this script makes a control paradigm to optimise the flow rates so that
% the airspeeds are minimised. 

%% ~~~~~~~~~~ CHOOSE PARADIGMS TO OPTIMISE ~~~~~~

nsteps=10;
npulses = 2;
%% make data vectors
cm = jet(10); % colour map
OptimisationData(1).CF = zeros(1,nsteps); % correction factor
OptimisationData(1).DA = zeros(1,nsteps); % delta airspeed
CorrectionFactor = ones(1,13); % this is to correct for non-equal flows b/w odour and control arms
% intialise. 
%% CORRECTION FACTORS FOR GLASS Y--inital conditions
CorrectionFactor(7) = 0.87;  % 1:5 dilution
CorrectionFactor(6) = 0.87;  % 1:3 dilution
CorrectionFactor(5) = 0.84;  % 1:2 dilution
CorrectionFactor(4) = 0.91;  % 1:1 dilution
CorrectionFactor(1) = 0.81;  % Inf:1 dilution

if iscell(OptimiseThese)
    % match names to paradigm IDs
    ControlParadigm = make_dilution_controls(300,3,CorrectionFactor);
    temp= (find(ismember({ControlParadigm.Name},OptimiseThese)));
    if length(temp) ~= length(OptimiseThese)
        error('Cant find the paradigms you want.')
        % this means that none of the paradigm names match some of the
        % names requested. 
    else
        OptimiseThese = temp;
        clear temp
    end
    
end
%% first check that control pulse is well balanced.
goon = 0;
ti=1;
while ~goon
    npulses = 5;
    disp('Checking that control pulse is OK, Iteration:')
    disp(ti)
    % make control paradigms 
    ControlParadigm = make_dilution_controls2(300,npulses,CorrectionFactor);

    % run the experiment
    data = Kontroller(0,ControlParadigm,11,1000);

    % figure out where the pulses are and the change in airspeed
    pulse = ControlParadigm(11).Outputs(6,:) + ControlParadigm(11).Outputs(5,:);
    pulse(1:12000) = 0;
    dp = diff(pulse); pulse= [];
    ons = find(dp==1);
    offs = find(dp==-1); 
    temp=[];
    for j = 2:length(ons) % skip first pulse
        temp = vertcat(temp, data(11).Airspeeds(ons(j)-1000:offs(j)+1000));
    end
    
    padding(11).m = mean(mean(temp(:,1:1000)'));
    padding(11).s = std(mean(temp(:,1:1000)'));  
    
    pulse(11).m = mean(mean(temp(:,1000:2000)'));
    pulse(11).s = std(mean(temp(:,1000:2000)'));
    if abs(pulse(11).m-padding(11).m) < min([pulse(11).s padding(11).s])
        disp('Control Pulses are OK. Going to try to fix odour pulses now.')
        % save what the control pulse looks like for later
        controlpulse = temp;
        goon=1;
        keyboard 
        
        
    else
        disp('Control Pulses are NOT OK. fix it now.')
        keyboard
    end
        
    
    
    
    ti = ti+1;
end

%% optimise
for i = OptimiseThese
    npulses=2;
    maxCF = 1.3;
    minCF = 0.7;
    thisCF = CorrectionFactor(i);
    % make figure
    figure, hold on, suptitle(strcat('Optimising Paradigm :',mat2str(i)))
    a(1) = subplot(2,2,1); hold on
    xlabel('Step #')
    ylabel('CorrectionFactor')
    a(2) = subplot(2,2,2); hold on
    ylabel('\Delta Airspeed')
    xlabel('Step #')
    a(3) = subplot(2,2,3); hold on
    ylabel('\Delta Airspeed')
    xlabel('CorrectionFactor')
    a(4) = subplot(2,2,4); hold off
    ylabel(' Airspeed')

    for k = 1:nsteps
        npulses=min(5,npulses+1);
        % update values
        OptimisationData(i).CF(k) = thisCF;
        CorrectionFactor(i) = thisCF;
        
        % make control paradigms 
        disp('Making control paradigms, using this CF:')
        disp(thisCF)
        ControlParadigm = make_dilution_controls2(300,npulses,CorrectionFactor);
        
        data = Kontroller(0,ControlParadigm,i,1000);

        pulse = ControlParadigm(i).Outputs(6,:) + ControlParadigm(i).Outputs(5,:);
        pulse(1:12000) = 0;
        dp = diff(pulse); pulse= [];
        ons = find(dp==1);
        offs = find(dp==-1);
        temp=[];
        for j = 2:length(ons)
            
            temp = vertcat(temp, data(i).Airspeeds(ons(j)-1000:offs(j)+1000));
        end

        padding(i).m = mean(mean(temp(:,1:1000)'));
        padding(i).s = std(mean(temp(:,1:1000)'));

        pulse(i).m = mean(mean(temp(:,1000:3000)'));
        pulse(i).s = std(mean(temp(:,1000:3000)'));
        
        % plot the airspeed trace
        cla(a(4))
        plot(a(4),mean(temp),'Color','k')
        hold on
        plot(mean(controlpulse),'b')
        title(strcat('Average of :',mat2str(npulses),' pulses'))
        

        % calculate the delta airspeed
        OptimisationData(i).DA(k) = -pulse(i).m+padding(i).m;
        
        % figure out wheter to increse or decrease CF
        % do something only if it gets better

        if k > 2
            if abs(OptimisationData(i).DA(k)) == min(abs(OptimisationData(i).DA)) 
                disp('Things getting better')
                    if OptimisationData(i).DA(k) < 0
                        % set min to current value
                        minCF = thisCF;
                        % increase CF
                        disp('Decrease in airspeed, so Increasing CF...')
                        thisCF = (thisCF+maxCF)/2;
                    else
                        % set max to current value
                        maxCF = thisCF;
                        % decrease CF
                        disp('INCREASE in airspeed, so decreasing CF...')
                        thisCF = (thisCF+minCF)/2;
                    end
            else
                disp('Things not getting better. Damn. Will use a linear prediction instead..')
                % fit a line to existing points and try to guess where the
                % correct setpoint is
                [f,gof]=fit(nonzeros(OptimisationData(i).DA),nonzeros(OptimisationData(i).CF),'poly1');
                thisCF = f(0);
                thisCF
                beep
                
            end
        else
            if OptimisationData(i).DA(k) < 0
                % set min to current value
                minCF = thisCF;
                % increase CF
                disp('first step, Decrease in airspeed, so Increasing CF...')
                thisCF = (thisCF+maxCF)/2;
            else
                % set max to current value
                maxCF = thisCF;
                % decrease CF
                disp('first step, INCREASE in airspeed, so decreasing CF...')
                thisCF = (thisCF+minCF)/2;
            end

        end
            

        
        % update correction factor plot
        scatter(a(1),k,OptimisationData(i).CF(k),'filled')
        
        % update Delta airspeed plot
        scatter(a(2),k,OptimisationData(i).DA(k),'filled')
        
        % update 3rd plot
        scatter(a(3),OptimisationData(i).CF(k),OptimisationData(i).DA(k))
        
    
    end
    % fit a line
    [f,gof]=fit(OptimisationData(i).CF',OptimisationData(i).DA','poly1');
    x=min(OptimisationData(i).CF):0.01:max(OptimisationData(i).CF);
    
    % plot it
    plot(a(3),x,f(x),'r','LineWidth',2)
    title(a(3),strcat('R-square:', oval(gof.rsquare,3)))
    
    title(a(4),strcat('Airspeed change :',oval(OptimisationData(i).DA(nsteps),3)))
    
    disp('Saving Data...')
    savename = strcat('C:\AutoTune Calibration Plots\AutoTune_',date,'_Paradigm_',mat2str(i),'-',uid,'.fig');
    saveas(gcf,savename);
    close(gcf)
    
end

%% at the end, make control paradigm with chosen T-pulse and save it
ControlParadigm = make_dilution_controls(300,PulseDuration,CorrectionFactor);
savename = strcat(date,'_Kontroller_Paradigm_AutoTuned_300_200ms.mat');
save(savename,'ControlParadigm');
% also make a 3-second long version
ControlParadigm = make_dilution_controls(300,3,CorrectionFactor);
savename = strcat(date,'_Kontroller_Paradigm_AutoTuned_300_3s.mat');
save(savename,'ControlParadigm');
% save the correction factor vector
savename = strcat('C:\AutoTune Calibration Plots\AutoTune_',date,'_',uid,'CF.mat');
save(savename,'CorrectionFactor');
