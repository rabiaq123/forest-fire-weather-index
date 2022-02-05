module FFWIndices

contains


subroutine allInfo()
      ! variables being read from file
      real :: prev_ffmc, prev_dmc, prev_dc, noon_rain, noon_temp
      integer :: start_month, days_of_data, days_in_month, humidity, wind
      integer, dimension(12) :: len_month
      real, dimension(12) :: day_length_dmc, day_length_dc
      ! variables used for final output
      real :: temp, rain
      integer :: month, date, int_ffmc, int_dmc, int_dc, int_isi, int_bui, int_fwi
      ! non-specific variables
      integer :: l, data_start_date
      real :: prev_rain, effective_rain
      ! FFMC variables
      real :: ffmc, rain_func_ffmc, post_rain_ffmc, prev_mc, drying_emc, wetting_emc, curr_final_mc
      real :: intermediate_drying_rate, log_drying_rate, correction_term_ffmc
      ! DMC variables
      real :: dmc, drying_factor_dmc, post_rain_dmc, mc_dmc, slope_func_dmc, mc_post_rain_dmc
      ! DC variables
      real :: dc, drying_factor_dc, moisture_equivalent_dc, post_rain_dc
      ! FWI, ISI, BUI variables
      real :: isi, bui, fwi, curr_ff_mc, ff_moisture_func, fix_bui_ratio_func, fix_bui_dmc_func
      real :: intermediate_fwi, log_final_fwi
      

!     INPUT VALUE FORMATTING

!     lengths of months and day-length factors
100   format(i2,f4.1,f4.1)
!     daily weather readings (temp, relative humidity, wind, rain)
101   format(f4.1,i4,i4,f4.1)
!     moisture codes' std starting values, starting month, and # of days data is provided
102   format(f4.1,f4.1,f5.1,i2,i2)

!     INPUT FILE READING 

!     read length of months and day-length factors
      do 20 month=1,12
      read(*,100) len_month(month), day_length_dmc(month), day_length_dc(month)
20    continue

!     read initial values of ffmc, dmc, dc, starting month, and
!     # of days weather data is provided that month.
      read(*,102) prev_ffmc, prev_dmc, prev_dc, start_month, days_of_data
      do 25 month=start_month,12
      days_in_month=len_month(month)
1002  format(10(/),1x,'  date  temp  rh   wind  rain   ffmc   dmc   dc   isi   bui   fwi'/)
      if(month==start_month) then
            data_start_date=len_month(month)-days_of_data+1
      else
            data_start_date=1
      end if

!     read daily weather data
      l=0
      do 25 date=data_start_date,days_in_month
      l=l+1
      read(*,101,end=2000) noon_temp,humidity,wind,noon_rain
      if(l==1) write(*,1002)
      temp=noon_temp
      rain=noon_rain

!     fine fuel moisture code
      if(noon_rain>0.5) go to 10
      noon_rain=0.0
      post_rain_ffmc=prev_ffmc
      go to 150
10    prev_rain=noon_rain
      if(prev_rain<=1.45) go to 6
      if(prev_rain-5.75) 9,9,12
6     rain_func_ffmc=123.85-(55.6*alog(prev_rain+1.016))
      go to 13
9     rain_func_ffmc=57.87-(18.2*alog(prev_rain-1.016))
      go to 13
12    rain_func_ffmc=40.69-(8.25*alog(prev_rain-1.905))
13    correction_term_ffmc=8.73*exp(-0.1117*prev_ffmc)
      post_rain_ffmc=(prev_ffmc/100.)*rain_func_ffmc+(1.0-correction_term_ffmc)
      if(post_rain_ffmc>=0.) go to 150
      post_rain_ffmc=0.0
150   prev_mc=101.-post_rain_ffmc
      drying_emc=0.942*(humidity**0.679)+(11.*exp((humidity-100.)/10.))+0.18*(21.1-noon_temp)*(1.-1./exp(0.115*humidity))
      if(prev_mc-drying_emc) 26,27,28
26    wetting_emc=0.618*(humidity**0.753)+(10.*exp((humidity-100.)/10.))+0.18*(21.1-noon_temp)*(1.-1./exp(0.115*humidity))
      if(prev_mc<wetting_emc) go to 29
27    curr_final_mc=prev_mc
      go to 30
28    intermediate_drying_rate=0.424*(1.-(humidity/100.)**1.7)+(0.0694*(wind**0.5))*(1.-(humidity/100.)**8)
      log_drying_rate=intermediate_drying_rate*(0.463*(exp(0.0365*noon_temp)))
      curr_final_mc=drying_emc+(prev_mc-drying_emc)/10.**log_drying_rate
      go to 30
29    curr_final_mc=wetting_emc-(wetting_emc-prev_mc)/1.9953
30    ffmc=101.-curr_final_mc
      if(ffmc>101.) go to 32
      if(ffmc) 33,34,34
32    ffmc=101.
      go to 34
33    ffmc=0.0

!     duff moisture code
34    if(noon_temp+1.1>=0.) go to 41
      noon_temp=-1.1
41    drying_factor_dmc=1.894*(noon_temp+1.1)*(100.-humidity)*(day_length_dmc(month)*0.0001)
43    if(noon_rain>1.5) go to 45
      post_rain_dmc=prev_dmc
      go to 250
45    prev_rain=noon_rain
      effective_rain=0.92*prev_rain-1.27
      mc_dmc=20.0+280./exp(0.023*prev_dmc)
      if(prev_dmc<=33.) go to 50
      if(prev_dmc-65.) 52,52,53
50    slope_func_dmc=100./(0.5+0.3*prev_dmc)
      go to 55
52    slope_func_dmc=14.-1.3*alog(prev_dmc)
      go to 55
53    slope_func_dmc=6.2*alog(prev_dmc)-17.2
55    mc_post_rain_dmc=mc_dmc+(1000.*effective_rain)/(48.77+slope_func_dmc*effective_rain)
      post_rain_dmc=43.43*(5.6348-alog(mc_post_rain_dmc-20.))
250   if(post_rain_dmc>=0.) go to 61
      post_rain_dmc=0.0
61    dmc=post_rain_dmc+drying_factor_dmc

!     drought code
      if(noon_temp+2.8>=0.) go to 65
      noon_temp=-2.8
65    drying_factor_dc=(.36*(noon_temp+2.8)+day_length_dc(month))/2.
      if(noon_rain<=2.8) go to 300
      prev_rain=noon_rain
      effective_rain=0.83*prev_rain-1.27
      moisture_equivalent_dc=800.*exp(-prev_dc/400.)
      post_rain_dc=prev_dc-400.*alog(1.+((3.937*effective_rain)/moisture_equivalent_dc))
      if(post_rain_dc>0.) go to 83
      post_rain_dc=0.0
83    dc=post_rain_dc+drying_factor_dc
      go to 350
300   post_rain_dc=prev_dc
      go to 83
350   if(dc>=0.) go to 85
      dc=0.0

!     initial spread index, buildup index, fire weather index
85    curr_ff_mc=101.-ffmc
      ff_moisture_func=19.1152*exp(-0.1386*curr_ff_mc)*(1.+curr_ff_mc**4.65/7950000.)
      isi=ff_moisture_func*exp(0.05039*wind)
93    bui=(0.8*dc*dmc)/(dmc+0.4*dc)
      if(bui>=dmc) go to 95
      ! ratio function to correct BUI when less than DMC
      fix_bui_ratio_func=(dmc-bui)/dmc
      ! DMC function to correct BUI when less than DMC
      fix_bui_dmc_func=0.92+(0.0114*dmc)**1.7
      bui=dmc-(fix_bui_dmc_func*fix_bui_ratio_func)
      if(bui<0.) bui=0.
95    if(bui>80.) go to 60
      intermediate_fwi=0.1*isi*(0.626*bui**0.809+2.)
      go to 91
60    intermediate_fwi=0.1*isi*(1000./(25.+108.64/exp(0.023*bui)))
91    if(intermediate_fwi-1.0<=0.) go to 98
      log_final_fwi=2.72*(0.43*alog(intermediate_fwi))**0.647
      fwi=exp(log_final_fwi)
      go to 400
98    fwi=intermediate_fwi

!     convert values to integer
400   int_dc=dc+0.5
      int_ffmc=ffmc+0.5
      int_dmc=dmc+0.5
      int_isi=isi+0.5
      int_bui=bui+0.5
      int_fwi=fwi+0.5
      write(*,1001) month,date,temp,humidity,wind,rain,int_ffmc,int_dmc,int_dc,int_isi,int_bui,int_fwi
1001  format(1x,2i3,f6.1,i4,i6,f7.1,6i6)
      prev_ffmc=ffmc
      prev_dmc=dmc
      prev_dc=dc
25    continue
2000  stop

return

end subroutine allInfo

end module FFWIndices
