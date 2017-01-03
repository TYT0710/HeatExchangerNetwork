%take input from user
%prompt = 'Please enter the desired streams in the following way: [Stream Numbers;mCp; Inlet T;Outlet T]\newline\n';
%asign input to Info
%Info = input(prompt);
Info=ye;
%prompt2='please enter the desired minimum temperature difference\n';
%deltaTmin=input(prompt2);
deltaTmin=10;
%Separate hot and cold streams and Temperature Intervals
[H,C,sizeH,sizeC,Tintervals]=hotcoldstreams(Info,deltaTmin);
%Cascade Diagram.. Need to find graphical representation
Sizeintervals=length(Tintervals);
mcpsum=zeros(Sizeintervals-1,1); heatbox=mcpsum; cumH=0; %intialize new counters, heat capacities and cum enthalpies
HeatUtility=mcpsum; Pinch=mcpsum; j=1;
for i=1:Sizeintervals-1
    hu=1;cu=1;
    while hu<=sizeH || cu<=sizeC
        %first check whether streams are within interval
        if hu>sizeH
        elseif Tintervals(i+1)<H(hu,3)...
                && Tintervals(i)>H(hu,4) 
            mcpsum(i)=mcpsum(i)+H(hu,2);
        end
        if cu>sizeC
        elseif Tintervals(i+1)<C(cu,4)+deltaTmin...
                && Tintervals(i)>C(cu,3)+deltaTmin
            mcpsum(i)=mcpsum(i)-C(cu,2);
        end
        hu=hu+1;
        cu=cu+1;
    end
    heatbox(i)=mcpsum(i)*(Tintervals(i)-Tintervals(i+1));
    cumH=cumH+heatbox(i);
    if cumH<=0
        Pinch(j)=Tintervals(i+1);
        HeatUtility(j)=-cumH;
        cumH=0;
        j=j+1;
    end
    if i+1==Sizeintervals
        ColdUtility=cumH;
    end
end
HeatUtility(j:end)=[];Pinch(j:end)=[];
%% Min No. Exchangers above and below pinch
%Find Cumulative Heat boxes above and below the pinch for specific streams
HotCumHa=[zeros(sizeH,1);HeatUtility]; ColdCumHa=zeros(sizeC,1);
HotCumHb=zeros(sizeH,1); ColdCumHb=[zeros(sizeC,1);ColdUtility];
Habove=zeros(sizeH,5); Hbelow=Habove;
Cabove=zeros(sizeC,5); Cbelow=Cabove;
a=1;b=1;
for i=1:sizeH
    if H(i,3)>Pinch
        if H(i,4)>Pinch
            HotCumHa(i)=(H(i,3)-H(i,4))*H(i,2);
            Habove(a,:)=[H(i,:),HotCumHa(i)]; %if completely above the pinch
        else
            HotCumHa(i)=(H(i,3)-Pinch)*H(i,2);
            HotCumHb(i)=(Pinch-H(i,4))*H(i,2);
            Habove(a,:)=[H(i,1:2),H(i,3),Pinch,HotCumHa(i)];
            Hbelow(b,:)=[H(i,1:2),Pinch,H(i,4),HotCumHb(i)];
        end
    else
        HotCumHb(i)=(H(i,3)-H(i,4))*H(i,2);
        Hbelow(b,:)=[H(i,:),HotCumHb(i)];
    end
    if Habove(a,5)<0.1 %make row=0
       Habove(a,:)=zeros(1,5);
    end
    if Hbelow(b,5)<0.1 %make row =0 if no heat can be transferred
       Hbelow(b,:)=zeros(1,5);
    end
    a=a+1;
    b=b+1;
end
a=1;b=1;
for i=1:sizeC
    if C(i,4)>Pinch-deltaTmin
        if C(i,3)>Pinch-deltaTmin
            ColdCumHa(i)=(C(i,4)-C(i,3))*C(i,2);
            Cabove(a,:)=[C(i,:),ColdCumHa(i)]; %if completely above the pinch
        else %if crosses pinch
            ColdCumHa(i)=(C(i,4)-Pinch+deltaTmin)*C(i,2);
            ColdCumHb(i)=(Pinch-deltaTmin-C(i,3))*C(i,2);
            Cabove(a,:)=[C(i,1:2),Pinch-deltaTmin,C(i,4),ColdCumHa(i)];
            Cbelow(b,:)=[C(i,1:2),C(i,3),Pinch-deltaTmin,ColdCumHb(i)];
        end
        
    else %if completely below pinch
        ColdCumHb(i)=(C(i,4)-C(i,3))*C(i,2);
        Cbelow(b,:)=[C(i,:),ColdCumHb(i)];
    end
    if Cabove(a,5)<0.1 %make row=0
       Cabove(a,:)=zeros(1,5);
    end
    if Cbelow(b,5)<0.1 %make row =0 if no heat can be transferred
       Cbelow(b,:)=zeros(1,5);
    end
    a=a+1;
    b=b+1;
end
%Find NMin above Pinch
%Heat exchangers are minimized by first finding good matches: that is,
%where the difference between the heat available vs the heat needed is 0
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
%%Find arrangement
%Habove=[H(:,; Cabove=C;


            



