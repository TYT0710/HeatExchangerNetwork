%%This script is meant to run the MUMNE algorithm
%Initialization of Variables: Take input from user
%prompt = 'Please enter the desired streams in the following way: [Stream Numbers;mCp; Inlet T;Outlet T]\newline\n';
%asign input to Info
%Info = input(prompt);
ye=[1 0.5 330 160;2 3 220 50;3 1.5 220 105;4 2.5 205 320;5 1 95 150;6 2 40 205];
Info=ye; %While debugging ye is used as an input
%%Indeces
global STREAMNO MCP TINLET TOUTLET ENTHALPY
STREAMNO=1;
MCP=2;
TINLET=3;
TOUTLET=4;
ENTHALPY=5;
%prompt2='please enter the desired minimum temperature difference\n';
%deltaTmin=input(prompt2);
deltaTmin=10;
%%Identify and Separate hot and cold streams and Temperature Intervals
[Hotstreams,Coldstreams,sizeH,sizeC,Tintervals]=hotcoldstreams(Info,deltaTmin);
%%Cascade Diagram.. Need to find graphical representation
[heatbox, HeatUtility, ColdUtility, Pinch]=Cascade(Tintervals, Hotstreams, Coldstreams, sizeH, sizeC,deltaTmin);
%% Min No. Exchangers above and below pinch
%Find Cumulative Heat boxes above and below the pinch for specific streams
%Nomenclature: HotCumHa=Cumulative Enthalpy of specific hot streams above
%pinch. ColdCumHa=Cumulative Enthalpy of specific cold streams above pinch.
%HotCumHb=Cumulative Enthalpy of specific hot streams below pinch.
%ColdCumHb=Cumulative Enthalpy of specific cold streams below the pinch. 
%These are necessary to find the minimum number of heat exchangers. 
%Habove=Hot Streams in table format similar to input variable but only for
%temperatures above the pinch. Cabove=Same as Habove but for cold streams.
%So far only single pinch is assumed. 
%PREALLOCATE VARIABLES
HotCumHa=[zeros(sizeH,1);HeatUtility]; ColdCumHa=zeros(sizeC,1);
HotCumHb=zeros(sizeH,1); ColdCumHb=[zeros(sizeC,1);ColdUtility];
Hotstreamsabove=zeros(sizeH,5); Hotstreamsbelow=Hotstreamsabove;
Coldstreamsabove=zeros(sizeC,5); Coldstreamsbelow=Coldstreamsabove;
a=1;b=1; %counters: a=above b=below
%Hot streams' enthalpy above and below is found by checking if the 
%temperatures cross or not the pinch temperature. If the temperature 
%crosses the pinch, then the heat of the stream must be split accordingly. 
for i=1:sizeH
    if Hotstreams(i,TINLET)>Pinch
        if Hotstreams(i,TOUTLET)>Pinch
            HotCumHa(i)=(Hotstreams(i,TINLET)-Hotstreams(i,TOUTLET))*Hotstreams(i,MCP);
            Hotstreamsabove(a,:)=[Hotstreams(i,:),HotCumHa(i)]; %if completely above the pinch
        else
            HotCumHa(i)=(Hotstreams(i,TINLET)-Pinch)*Hotstreams(i,MCP);
            HotCumHb(i)=(Pinch-Hotstreams(i,TOUTLET))*Hotstreams(i,MCP);
            Hotstreamsabove(a,:)=[Hotstreams(i,1:2),Hotstreams(i,TINLET),Pinch,HotCumHa(i)];
            Hotstreamsbelow(b,:)=[Hotstreams(i,1:2),Pinch,Hotstreams(i,TOUTLET),HotCumHb(i)];
        end
    else
        HotCumHb(i)=(Hotstreams(i,TINLET)-Hotstreams(i,TOUTLET))*Hotstreams(i,MCP);
        Hotstreamsbelow(b,:)=[Hotstreams(i,:),HotCumHb(i)];
    end
    if Hotstreamsabove(a,ENTHALPY)<0.1 %make row=0
       Hotstreamsabove(a,:)=zeros(1,ENTHALPY);
    end
    if Hotstreamsbelow(b,ENTHALPY)<0.1 %make row =0 if no heat can be transferred
       Hotstreamsbelow(b,:)=zeros(1,5);
    end
    a=a+1;
    b=b+1;
end
%Similar for loop for the cold streams. 
a=1;b=1;
for i=1:sizeC
    if Coldstreams(i,TOUTLET)>Pinch-deltaTmin
        if Coldstreams(i,TINLET)>Pinch-deltaTmin
            ColdCumHa(i)=(Coldstreams(i,TOUTLET)-Coldstreams(i,TINLET))*Coldstreams(i,MCP);
            Coldstreamsabove(a,:)=[Coldstreams(i,:),ColdCumHa(i)]; %if completely above the pinch
        else %if crosses pinch
            ColdCumHa(i)=(Coldstreams(i,TOUTLET)-Pinch+deltaTmin)*Coldstreams(i,MCP);
            ColdCumHb(i)=(Pinch-deltaTmin-Coldstreams(i,TINLET))*Coldstreams(i,MCP);
            Coldstreamsabove(a,:)=[Coldstreams(i,1:2),Pinch-deltaTmin,Coldstreams(i,TOUTLET),ColdCumHa(i)];
            Coldstreamsbelow(b,:)=[Coldstreams(i,1:2),Coldstreams(i,TINLET),Pinch-deltaTmin,ColdCumHb(i)];
        end
        
    else %if completely below pinch
        ColdCumHb(i)=(Coldstreams(i,TOUTLET)-Coldstreams(i,TINLET))*Coldstreams(i,MCP);
        Coldstreamsbelow(b,:)=[Coldstreams(i,:),ColdCumHb(i)];
    end
    if Coldstreamsabove(a,ENTHALPY)<0.1 %make row=0
       Coldstreamsabove(a,:)=zeros(1,5);
    end
    if Coldstreamsbelow(b,ENTHALPY)<0.1 %make row =0 if no heat can be transferred
       Coldstreamsbelow(b,:)=zeros(1,5);
    end
    a=a+1;
    b=b+1;
end
%%Find NMin above and below Pinch
%Heat exchangers are minimized by first finding good matches: that is,
%where the difference between the heat available vs the heat needed is 0
%we make a first nested for loop to compare if heat rates match. 
%If not, then a generalized equation can be used to find the min. number of
%exchangers. This is necessary because it will be the objective function
%for the stream matching step later on. HotCumHarefined is essentially the
%same thing as HotCumHa, yet the streams that match perfectly are taken out
%for the generalized equation to work. 
HotCumHarefined=HotCumHa; ColdCumHarefined=ColdCumHa; NEA=0;
HotCumHbrefined=HotCumHb; ColdCumHbrefined=ColdCumHb; NEB=0;
for i=1:sizeC
    for j=1:sizeH
        if ColdCumHa(i)==0
        elseif HotCumHa(j)==0
        elseif abs(HotCumHa(j)-ColdCumHa(i))<1e-3
            HotCumHarefined(j-NEA)=[]; ColdCumHarefined(i-NEA)=[]; %taken out of consideration
            NEA=NEA+1;
        end
        if ColdCumHb(i)==0
        elseif HotCumHa(j)==0
        elseif abs(HotCumHb(j)-ColdCumHb(i))<1e-3
            HotCumHbrefined(j-NEB)=[]; ColdCumHbrefined(i-NEB)=[]; %taken out of consideration
            NEB=NEB+1;
        end
    end
end
NEA=NEA+length(HotCumHarefined(HotCumHarefined>0))+length(ColdCumHarefined(ColdCumHarefined>0))-1; %this formula seems to work. Need to take away 0 values though lol
NEB=NEB+length(HotCumHbrefined(HotCumHbrefined>0))+length(ColdCumHbrefined(ColdCumHbrefined>0))-1;
%%Stream Matching
%Above the pinch, hot stream cooling takes priority over cold stream
%heating. 
%% Sort according to heat capacities
Hotstreamsabove=newquicksortcoldescending(Hotstreamsabove,1,sizeH,TINLET);
Coldstreamsabove=newquicksortcoldescending(Coldstreamsabove,1,sizeC,TOUTLET);
Hotstreamsbelow=newquicksortcoldescending(Hotstreamsbelow,1,sizeH,TINLET);
Coldstreamsbelow=newquicksortcoldescending(Coldstreamsbelow,1,sizeC,TOUTLET);
%First try without splitting. Big loop cycles through hot streams


            



