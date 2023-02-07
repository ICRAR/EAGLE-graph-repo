#!/bin/sh

ulimit -n 4096 
ulimit -a
if [[ ! -v SLURM_JOB_NAME ]]; then
   SLURM_JOB_NAME=Test_Job.$$
fi
if [[ ! -v SLURM_ARRAY_TASK_ID ]]; then
      SLURM_ARRAY_TASK_ID=0
fi
echo 'Slurm Job Name and number set to ',$SLURM_JOB_NAME, $SLURM_ARRAY_TASK_ID
   
cat >$SLURM_JOB_NAME.$SLURM_ARRAY_TASK_ID.sh <<ENDIN

# Define a proc
def time_convert(mytime, myunit='s'):
    if type(mytime).__name__ != 'list': mytime=[mytime]
    myTimestr = []
    for time in mytime:
        q1=qa.quantity(time,myunit)
        time1=qa.time(q1,form='ymd')
        myTimestr.append(time1)
    return myTimestr


# get NumPy
import numpy as np
import glob,os
SplitArea='/scratch/pawsey0411/chiles/Split'
os.system('mkdir -p %s'%(SplitArea))
os.chdir(SplitArea)

phasecenters        =  ["J2000 10h01m24.00 2d21m00.00",'J2000 10h03m14.8 01d21m22.6', 'J2000 10h05m20 02d31m00', 'J2000 10h04m40 03d20m00', 'J2000 09h58m25.0 03d24m10.0', 'J2000 09h57m10.0 02d55m10.0','J2000 09h59m20.0 01d18m00.0','J2000 10h01m22.154 -00d26m06.6']

vis='$1'
print(vis)
for o in range(len(phasecenters)):
       outputvis='O%d-%s'%(o,vis[(vis.rindex('/')+1):].replace('ms','fixvis.ms'))
       phasecenter=phasecenters[o]
       os.system('rm -r %s'%(outputvis))
       if o>0: 
           fixvis(vis=vis,outputvis=outputvis,phasecenter=phasecenter)
       for nspw in range(15):
          ovis2=outputvis.replace('fixvis','spw%02d'%(nspw))
          os.system('rm -r %s'%(ovis2))
          if o==0: 
             split(vis=vis,outputvis=ovis2,width=32,spw=str(nspw),datacolumn='data')
          else:
             split(vis=outputvis,outputvis=ovis2,width=32,spw=str(nspw),datacolumn='data')
          ms.open(ovis2)
          ret=ms.getdata(['axis_info','ha'],ifraxis=True)
          if (len(ret)): # if null MS ret is zero length
              ha= ret['axis_info']['time_axis']['HA']/3600.0
              ut = np.mod(ret['axis_info']['time_axis']['MJDseconds']/3600.0/24.0,1)*24.0
              for m in range(-16,16):
                  os.system('mkdir -p '+SplitArea+'/HA_'+str(m))
                  outputvis2=SplitArea+'/HA_'+str(m)+'/'+ovis2
                  os.system('rm -r '+outputvis2)
                  ptr=np.where(ha>(m/2.0))[0]
                  if (os.path.exists(outputvis2)):
                      ptr=[]
                  if (len(ptr)):
                      print('Working on'+outputvis2)
                      ptr=ptr[0]
                      ut_start=ut[ptr]
                      ut_start
                      #q1=qa.quanity(ret['axis_info']['time_axis']['MJDseconds'][ptr],'s')
                      #date_start=qa.time(q1,form='ymd')
                      date_start=time_convert(ret['axis_info']['time_axis']['MJDseconds'][ptr])[0][0]
                      ptr=np.where(ha>((m+1)/2.0))[0]
                      if (len(ptr)==0):
                          ptr=-1
                      else:
                          ptr=ptr[0]
                      ut_end=ut[ptr]
                      #q1=qa.quanity(ret['axis_info']['time_axis']['MJDseconds'][ptr],'s')
                      #date_end=qa.time(q1,form='ymd')
                      date_end=time_convert(ret['axis_info']['time_axis']['MJDseconds'][ptr])[0][0]
                      if (ut_end<ut_start):
                          ut_end=ut_end+24
                      timerange=str(ut_start)+'~'+str(ut_end)
                      timerange=date_start+'~'+date_end
                      print('Timerange: '+str(timerange))
                      #inp()
                      if (ut_end!=ut_start):
                          split(timerange=timerange,vis=ovis2,outputvis=outputvis2,datacolumn='data')
          ms.close()
          os.system('rm -r %s'%(ovis2))
       os.system('rm -r %s'%(outputvis))
exit()
ENDIN

#/software/projects/pawsey0411/casa-6.5.2-26-py3.8/bin/casa --nologger --log2term -c $SLURM_JOB_NAME.$SLURM_ARRAY_TASK_ID.sh
