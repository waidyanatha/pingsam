import numpy as np
import datetime as dtm
from dateutil import rrule
import pandas as pd
import csv
import matplotlib.pylab as plt
#lets first create the csv file
#
#change this to actual csv file name
pingfile="weeklylogs.csv"
#paramters @plotinterval = 10 minutes
plotinterval = 10
#csv file columns
col_seq=0
col_pingtime=1
col_domain=2
col_state=3
#
########## FUNCTION TO SYNTHESEIZE MISSING DATA POINTS ##########
#
def synth_data(synthdf, interval):
    #create a temporary dataframe to hold the syntheseized data
    tmpdf = pd.DataFrame(columns=['seqnum', 'pingdatetime', 'domain', 'statenow'])
    #first check we have a none empty dataframe
    if not synthdf.empty:
        #pick the originating TS data point
        synthdf.sort_values(by='pingdatetime')
        #startdt = synthdf.index.min()
        startseqnum = synthdf.index[0]
        startpingdt = synthdf.iloc[0]['pingdatetime']
        startdomain = synthdf.iloc[0]['domain']
        startstate = synthdf.iloc[0]['statenow']
        #loop through each TS data point to synthetically add new TS points
        #to fill the gap between two consecutive data points
        for i, row in synthdf.iterrows():
            #initiate the synthesiezed data point to the origin
            nextdatapoint = 0
            pingdt_plus_interval = startpingdt
            #stepwise loop to add syntheseized points from relative origin to the next TS data point
            while row['pingdatetime'] > pingdt_plus_interval + dtm.timedelta(minutes = interval) :
                nextdatapoint += 1
                pingdt_plus_interval = startpingdt + dtm.timedelta(minutes = nextdatapoint*interval)
                tmpdf.loc[len(tmpdf.index)] = [startseqnum,pingdt_plus_interval,startdomain,startstate]
            startseqnum = i
            startpingdt = row['pingdatetime']
#d            startdomain = row['domain']
            startstate = row['statenow']
            
        #after completing through all the TS datapoints check if a none empty dataframe was created
        if not tmpdf.empty:
            #tmpdf.sort_values(by='pingdatetime')
            tmpdf = tmpdf.set_index('seqnum')
    #whether null or not return a dataframe with syntheseized TS data
    tmpdf.dropna(thresh=2)
    return tmpdf
#
########## PLOT HISTOGRAM TO FIGURE ##########
#
def plot_hist_to_fig(histdf, dname):
    #get date range of the plot to use in suptitile
    begdt = histdf['pingdatetime'].min().date()
    findt = histdf['pingdatetime'].max().date()
    #create a new x-axis index using dataframe index; starting from 1 instead of 0
#d    histdf['xvalues'] = range(1,len(histdf)+1)
    histdf['pingdate'] = histdf['pingdatetime'].apply(lambda x: x.date())
    downdf = pd.DataFrame(columns=['xlabel','pingdate', 'downcount'])
    datelist = list(histdf.pingdate.unique())
    for uniquedate in datelist:
        xlabel = str('{:02d}'.format(uniquedate.month))+'-'+str('{:02d}'.format(uniquedate.day))
        downcount = len(histdf[(histdf.statenow == '0') & (histdf.pingdate == uniquedate)])
        totalcount = len(histdf[(histdf.pingdate == uniquedate)])
        downdf.loc[len(downdf.index)] = [xlabel, uniquedate,100*downcount//totalcount]
    downdf = downdf.as_matrix()
    #x-axis values are in the newly generated xvalues column
    xl = np.array(downdf[:,0])
    x = np.array(downdf[:,1])
    #y-axis values (1 or 0) are in the dateframe statenow column
    y = np.array(downdf[:,2])

#    histfig = plt.figure(num=None, figsize=(8, 6), dpi=150, facecolor='w', edgecolor='k')
#    plt.hist(downdf[:,1], cumulative=False)
#    ax = histfig.add_subplot(211)
    histfig, ax = plt.subplots()
#    ax.bar(ind + width, women_means, width, color='y', yerr=women_std)
#    ax.plot(x,y,color='green',lw=2)
    ax.bar(x,y,color='red',width=0.5, align="center")
    #to give enough spacing for the suptitle; otherwise overlaps with title
    histfig.subplots_adjust(top=0.87)
    #beautify the plot and name the labels, titles
    ax.set_title('Percentage of time Server Failed each Day', fontsize=14, fontweight='bold', color='gray')
    histfig.suptitle(dname+'\n'+str(begdt)+' --- '+str(findt), fontsize=10, color='blue')
    ax.set_xlabel('Month-Day', fontsize=12, color='gray')
    ax.set_ylabel('Faile Rate (%)', fontsize=12, color='gray')
    plt.yticks(fontsize=10, color='gray', rotation='horizontal')
    plt.xticks(x, xl, fontsize=10, color='gray', rotation='horizontal')
    ax.grid(True)

    return histfig
#
########## PLOT DOWN TIMES FREQUENCY TO FIGURE ##########
#
def plot_freq_to_fig(plotdf, dname):
    #get date range of the plot to use in suptitile
    begdt = plotdf['pingdatetime'].min().date()
    findt = plotdf['pingdatetime'].max().date()
    failrate = 100-(sum(100*plotdf['statenow'].astype(int))/len(plotdf))
    failrate = failrate.astype(float)
    #create a new x-axis index using dataframe index; starting from 1 instead of 0
    plotdf['xvalues'] = range(1,len(plotdf)+1)
    plotdf = plotdf.as_matrix()
    #x-axis values are in the newly generated xvalues column
    x = np.array(plotdf[:,3].astype(int))
    #y-axis values (1 or 0) are in the dateframe statenow column
    y = np.array(plotdf[:,2].astype(int))
    
    #setup to catputure the plot into a figure
    plotfig = plt.figure(num=None, figsize=(8, 6), dpi=150, facecolor='w', edgecolor='k')
    ax = plotfig.add_subplot(311)
    ax.plot(x,y,color='green',lw=2)
    #to give enough spacing for the suptitle; otherwise overlaps with title
    plotfig.subplots_adjust(top=0.87)
    #beautify the plot and name the labels, titles
    ax.set_title('Frequency of Server Access Failure ('+str(failrate)+'%)', fontsize=14, fontweight='bold', color='gray')
    plotfig.suptitle(dname+'\n'+str(begdt)+' --- '+str(findt), fontsize=10, color='blue')
    ax.set_xlabel('Attempted Machine Accesss Times', fontsize=12, color='gray')
    ax.set_ylabel('Machine State', fontsize=12, color='gray')
    plt.yticks(y, ['UP','DOWN'], fontsize=10, color='gray', rotation='vertical')
    plt.xticks(fontsize=10, color='gray', rotation='horizontal')
    ax.grid(True)

    return plotfig
#
############# MAIN ################################
#
print("Reading data from file "+pingfile)
with open(pingfile, 'rb') as f:
    data = [i.split(",") for i in f.read().split()]
    df = pd.DataFrame(data, columns=['seqnum', 'pingdatetime', 'domain', 'statenow'])
    for index, row in df.iterrows():
        row[col_pingtime] = dtm.datetime.strptime(row[col_pingtime], '%Y-%m-%d:%H:%M:%S')
    #format pingdatetime as proper datetime, set it as the indext and then order them
    df['pingdatetime'] = pd.to_datetime(df['pingdatetime'])
    df.sort_values(by='pingdatetime')
    df = df.set_index('seqnum')
    #begin processing for each unique domain
    print(str(len(df.index))+" data rows added to the dataframe, ready for processing ...")
    print ('-----------------------------------------------------')
    for thedomain in df.domain.unique():
        #insert syntheseised data points
        dompingdf = df[df['domain']==thedomain]
        print("Begin data synthesis for "+thedomain+" with data rows = "+str(len(dompingdf.index)))
        amenddf = synth_data(dompingdf,plotinterval)
        if not amenddf.empty:
            #output the syntheseized dataframe to output file
            print(str(len(amenddf.index))+" data rows of syntheseised added to "+thedomain )
            finaldf = pd.concat([dompingdf,amenddf])
            finaldf['pingdatetime'] = pd.to_datetime(finaldf.pingdatetime)
            finaldf = finaldf.sort(['pingdatetime'])
            finaldf.index = range(0,len(finaldf))
            print('writing data to file: ./data/syndata_'+thedomain+'.csv')
            finaldf.to_csv('./data/syndata_'+thedomain+'.csv')
            #plot timeseries with function (need to add if conditions to check if function returns valid fig)
            fig = plot_freq_to_fig(finaldf, thedomain)
            fig.savefig('./plots/freqplot_'+thedomain+'.png', bbox_inches='tight')
            print ('frequency plot created in file: ./plots/freqplot_'+thedomain+'.png')
            fig = plot_hist_to_fig(finaldf, thedomain)
            fig.savefig('./plots/histplot_'+thedomain+'.png', bbox_inches='tight')
            print ('histogram plot created in file: ./plots/histplot_'+thedomain+'.png')
            print ('process complete for '+thedomain)
            print ('-----------------------------------------------------')

        else:
            print ("Warning: no syntheseized data was added to: "+thedomain)
