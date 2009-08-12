      SUBROUTINE INITPOST
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!                .      .    .     
! SUBPROGRAM:    INITPOST    INITIALIZE POST FOR RUN
!   PRGRMMR: RUSS TREADON    ORG: W/NP2      DATE: 93-11-10
!     
! ABSTRACT:  THIS ROUTINE INITIALIZES CONSTANTS AND
!   VARIABLES AT THE START OF AN ETA MODEL OR POST 
!   PROCESSOR RUN.
!
!   THIS ROUTINE ASSUMES THAT INTEGERS AND REALS ARE THE SAME SIZE
!   .     
!     
! PROGRAM HISTORY LOG:
!   93-11-10  RUSS TREADON - ADDED DOCBLOC
!   98-05-29  BLACK - CONVERSION OF POST CODE FROM 1-D TO 2-D
!   99-01 20  TUCCILLO - MPI VERSION
!   01-10-25  H CHUANG - MODIFIED TO PROCESS HYBRID MODEL OUTPUT
!   02-06-19  MIKE BALDWIN - WRF VERSION
!   02-08-15  H CHUANG - UNIT CORRECTION AND GENERALIZE PROJECTION OPTIONS
!     
! USAGE:    CALL INIT
!   INPUT ARGUMENT LIST:
!     NONE     
!
!   OUTPUT ARGUMENT LIST: 
!     NONE
!     
!   OUTPUT FILES:
!     NONE
!     
!   SUBPROGRAMS CALLED:
!     UTILITIES:
!       NONE
!     LIBRARY:
!       COMMON   - CTLBLK
!                  LOOKUP
!                  SOILDEPTH
!
!    
!   ATTRIBUTES:
!     LANGUAGE: FORTRAN
!     MACHINE : CRAY C-90
!$$$  
      use vrbls3d
      use vrbls2d
      use soil
      use masks
      use ctlblk_mod
      use params_mod
      use lookup_mod
      use gridspec_mod
      use wrf_io_flags_mod
!- - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - -
      implicit none
!
!     INCLUDE/SET PARAMETERS.
!     
      INCLUDE "mpif.h"
!
! This version of INITPOST shows how to initialize, open, read from, and
! close a NetCDF dataset. In order to change it to read an internal (binary)
! dataset, do a global replacement of _ncd_ with _int_. 

      character(len=31) :: VarName
      integer :: Status
      character startdate*19,SysDepInfo*80
! 
!     NOTE: SOME INTEGER VARIABLES ARE READ INTO DUMMY ( A REAL ). THIS IS OK
!     AS LONG AS REALS AND INTEGERS ARE THE SAME SIZE.
!
!     ALSO, EXTRACT IS CALLED WITH DUMMY ( A REAL ) EVEN WHEN THE NUMBERS ARE
!     INTEGERS - THIS IS OK AS LONG AS INTEGERS AND REALS ARE THE SAME SIZE.
      LOGICAL RUNB,SINGLRST,SUBPOST,NEST,HYDRO
      LOGICAL IOOMG,IOALL
      CHARACTER*32 LABEL
      CHARACTER*40 CONTRL,FILALL,FILMST,FILTMP,FILTKE,FILUNV           &
     &, FILCLD,FILRAD,FILSFC
      CHARACTER*4 RESTHR
      CHARACTER FNAME*80,ENVAR*50,BLANK*4
      INTEGER IDATB(3),IDATE(8),JDATE(8)
!
!     DECLARE VARIABLES.
!     
      REAL RINC(5)
      REAL SLDPTH2(NSOIL)
      REAL DUMMY ( IM, JM )
      REAL DUMMY2 ( IM, JM ), MSFT(IM,JM)
      INTEGER IDUMMY ( IM, JM )
      REAL DUM3D ( IM+1, JM+1, LM+1 )
      REAL DUM3D2 ( IM+1, JM+1, LM+1 )
        real, allocatable::  pvapor(:,:)
        real, allocatable::  pvapor_orig(:,:)      
!jw
      integer js,je,jev,iyear,imn,iday,itmp,ioutcount,istatus,          &
              ii,jj,ll,i,j,l,nrdlw,nrdsw,n,igdout,irtn,idyvald,        &
              idxvald,NSRFC
      real DZ,TSPH,TMP,QMEAN,PVAPORNEW,DUMCST,TLMH,RHO
!
      DATA BLANK/'    '/
!
!***********************************************************************
!     START INIT HERE.
!
      WRITE(6,*)'INITPOST:  ENTER INITPOST'
!     
!     STEP 1.  READ MODEL OUTPUT FILE
!
!
!***
!
! LMH always = LM for sigma-type vert coord
! LMV always = LM for sigma-type vert coord

       do j = jsta_2l, jend_2u
        do i = 1, im
            LMV ( i, j ) = lm
            LMH ( i, j ) = lm
        end do
       end do


! HTM VTM all 1 for sigma-type vert coord

      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            HTM ( i, j, l ) = 1.0
            VTM ( i, j, l ) = 1.0
        end do
       end do
      end do
!
!  how do I get the filename? 
!      fileName = '/ptmp/wx20mb/wrfout_01_030500'
!      DateStr = '2002-03-05_18:00:00'
!  how do I get the filename?
         call ext_ncd_ioinit(SysDepInfo,Status)
          print*,'called ioinit', Status
         call ext_ncd_open_for_read( trim(fileName), 0, 0, " ",        &  
            DataHandle, Status)
          print*,'called open for read', Status
       if ( Status /= 0 ) then
         print*,'error opening ',fileName, ' Status = ', Status ; stop
       endif
! get date/time info
!  this routine will get the next time from the file, not using it
      print *,'DateStr before calling ext_ncd_get_next_time=',DateStr
!      call ext_ncd_get_next_time(DataHandle, DateStr, Status)
      print *,'DateStri,Status,DataHandle = ',DateStr,Status,DataHandle

!  The end j row is going to be jend_2u for all variables except for V.
      JS=JSTA_2L
      JE=JEND_2U
      IF (JEND_2U.EQ.JM) THEN
       JEV=JEND_2U+1
      ELSE
       JEV=JEND_2U
      ENDIF
!
! Getting start time
      call ext_ncd_get_dom_ti_char(DataHandle,'START_DATE',startdate,   &
        status )
        print*,'startdate= ',startdate
      jdate=0
      idate=0
      read(startdate,15)iyear,imn,iday,ihrst,imin      
 15   format(i4,1x,i2,1x,i2,1x,i2,1x,i2)
      print*,'start yr mo day hr min=',iyear,imn,iday,ihrst,imin
      print*,'processing yr mo day hr min='                             &
        ,idat(3),idat(1),idat(2),idat(4),idat(5)
      idate(1)=iyear
      idate(2)=imn
      idate(3)=iday
      idate(5)=ihrst
      idate(6)=imin
      SDAT(1)=imn
      SDAT(2)=iday
      SDAT(3)=iyear
      jdate(1)=idat(3)
      jdate(2)=idat(1)
      jdate(3)=idat(2)
      jdate(5)=idat(4)
      jdate(6)=idat(5)
!      CALL W3DIFDAT(JDATE,IDATE,2,RINC)
!      ifhr=nint(rinc(2))
      CALL W3DIFDAT(JDATE,IDATE,0,RINC)
      ifhr=nint(rinc(2)+rinc(1)*24.)
      ifmin=nint(rinc(3))
      print*,' in INITPOST ifhr ifmin fileName=',ifhr,ifmin,fileName
!  OK, since all of the variables are dimensioned/allocated to be
!  the same size, this means we have to be careful int getVariable
!  to not try to get too much data.  For example, 
!  DUM3D is dimensioned IM+1,JM+1,LM+1 but there might actually
!  only be im,jm,lm points of data available for a particular variable.  

      call ext_ncd_get_dom_ti_integer(DataHandle,'MP_PHYSICS'          &
       ,itmp,1,ioutcount,istatus)
      imp_physics=itmp
      print*,'MP_PHYSICS= ',itmp
      
      call ext_ncd_get_dom_ti_integer(DataHandle,'CU_PHYSICS'          &
       ,itmp,1,ioutcount,istatus)
        icu_physics=itmp
        print*,'CU_PHYSICS= ',icu_physics
	
! get 3-D variables
      print*,'im,jm,lm= ',im,jm,lm
      ii=10
      jj=jend
      ll=lm
      VarName='T'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
!            t ( i, j, l ) = dum3d ( i, j, l ) + 300.
             t ( i, j, l ) = dum3d ( i, j, l ) + 300.
!MEB  this is theta the 300 is my guess at what T0 is 
        end do
       end do
      end do
      ii=im/2
      jj=(jsta+jend)/2
      ll=lm/2
!      if(jj.ge. jsta .and. jj.le.jend)print*,'sample TH= ',TH(ii,jj,ll)
      do l=1,lm
      end do
      VarName='U'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM+1,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im+1
            u ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
!  fill up UH which is U at P-points including 2 row halo
       do j = jsta_2l, jend_2u
        do i = 1, im
            UH (I,J,L) = (dum3d(I,J,L)+dum3d(I+1,J,L))*0.5
        end do
       end do
      end do
!      if(jj.ge. jsta .and. jj.le.jend)print*,'sample U= ',U(ii,jj,ll)
      VarName='V'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JEV,LM)
      do l = 1, lm
       do j = jsta_2l, jev
        do i = 1, im
            v ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
!  fill up VH which is V at P-points including 2 row halo
       do j = jsta_2l, jend_2u
        do i = 1, im
          VH(I,J,L) = (dum3d(I,J,L)+dum3d(I,J+1,L))*0.5
        end do
       end do
      end do
!      if(jj.ge. jsta .and. jj.le.jend)print*,'sample V= ',V(ii,jj,ll)

      VarName='W'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM+1)
!      do l = 1, lm+1
!       do j = jsta_2l, jend_2u
!        do i = 1, im
!            w ( i, j, l ) = dum3d ( i, j, l )
!        end do
!       end do
!      end do
!  fill up WH which is W at P-points including 2 row halo
      DO L=1,LM
        DO I=1,IM
         DO J=JSTA_2L,JEND_2U 
          WH(I,J,L) = (DUM3D(I,J,L)+DUM3D(I,J,L+1))*0.5
         ENDDO
        ENDDO
      ENDDO
      print*,'finish reading W'

      VarName='QVAPOR'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            q ( i, j, l ) = dum3d ( i, j, l )
!HC CONVERT MIXING RATIO TO SPECIFIC HUMIDITY
            q ( i, j, l ) = dum3d ( i, j, l )/(1.0+dum3d ( i, j, l ))
        end do
       end do
      end do
      print*,'finish reading mixing reatio'
!      if(jj.ge. jsta .and. jj.le.jend)print*,'sample Q= ',Q(ii,jj,ll)

      VarName='PB'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      VarName='P'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D2,        &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            PMID(I,J,L)=DUM3D(I,J,L)+DUM3D2(I,J,L)
! now that I have P, convert theta to t
!            t ( i, j, l ) = T(I,J,L)*(PMID(I,J,L)*1.E-5)**CAPA
             t ( i, j, l ) = T(I,J,L)*(PMID(I,J,L)*1.E-5)**CAPA
! now that I have T,q,P  compute omega from wh
             if(abs(t( i, j, l )).gt.1.0e-3)                              &
              omga(I,J,L) = -WH(I,J,L)*pmid(i,j,l)*G/                     &
                              (RD*t(i,j,l)*(1.+D608*q(i,j,l)))
! seperate rain from snow and cloud water from cloud ice for WSM3 scheme
!             if(imp_physics .eq. 3)then
!	      if(t(i,j,l) .lt. TFRZ)then
!	       qqs(i,j,l)=qqr(i,j,l)
!	       qqi(i,j,l)=qqw(i,j,l)
!	      end if 
!	     end if 	                      
        end do
       end do
      end do
      DO L=2,LM
         DO I=1,IM
            DO J=JSTA_2L,JEND_2U
              PINT(I,J,L)=(PMID(I,J,L-1)+PMID(I,J,L))*0.5 
              ALPINT(I,J,L)=ALOG(PINT(I,J,L))
            ENDDO
         ENDDO
      ENDDO

! Brad comment out the output of individual species for Ferrier's scheme within
! ARW in Registry file

      qqw=0.
      qqr=0.
      qqs=0.
      qqi=0.
      qqg=0. 
      cwm=0.
      
      if(imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QCLOUD'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
! partition cloud water and ice for WSM3 
	    if(imp_physics.eq.3)then 
             if(t(i,j,l) .ge. TFRZ)then  
              qqw ( i, j, l ) = dum3d ( i, j, l )
	     else
	      qqi  ( i, j, l ) = dum3d ( i, j, l )
	     end if
            else ! bug fix provided by J CASE
             qqw ( i, j, l ) = dum3d ( i, j, l )
	    end if  	     
        end do
       end do
      end do
!      if(jj.ge. jsta .and. jj.le.jend)
!     + print*,'sample QCLOUD= ',QQW(ii,jj,ll)
!      print*,'finish reading cloud mixing ratio'
      end if 
      


      if(imp_physics.ne.1 .and. imp_physics.ne.3                          &
        .and. imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QICE'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            qqi ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do
!      if(jj.ge. jsta .and. jj.le.jend)
!     + print*,'sample QICE= ',qqi(ii,jj,ll)
      end if
      

      if(imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QRAIN'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
! partition rain and snow for WSM3 	
          if(imp_physics .eq. 3)then
	    if(t(i,j,l) .ge. TFRZ)then  
             qqr ( i, j, l ) = dum3d ( i, j, l )
	    else
	     qqs ( i, j, l ) = dum3d ( i, j, l )
	    end if
           else ! bug fix provided by J CASE
            qqr ( i, j, l ) = dum3d ( i, j, l )  
	   end if 
            dummy(i,j)=dum3d(i,j,l)
        end do
       end do
       print*,'max rain water= ',l,maxval(dummy)
      end do
!      if(jj.ge. jsta .and. jj.le.jend)
!     + print*,'sample QRAIN= ',qqr(ii,jj,ll)
      end if 
     

      if(imp_physics.ne.1 .and. imp_physics.ne.3 .and.                    &
         imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QSNOW'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,         &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            qqs ( i, j, l ) = dum3d ( i, j, l )
            dummy(i,j)=dum3d(i,j,l)
        end do
       end do
       print*,'max snow= ',l,maxval(dummy)
      end do
!      if(jj.ge. jsta .and. jj.le.jend)
!     + print*,'sample QSNOW= ',qqs(ii,jj,ll)
      end if
      

      if(imp_physics.eq.2 .or. imp_physics.eq.6                          &
         .or. imp_physics.eq.8)then
      VarName='QGRAUP'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            qqg ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do
!      if(jj.ge. jsta .and. jj.le.jend)
!     + print*,'sample QGRAUP= ',qqg(ii,jj,ll)
      end if  


      if(imp_physics.ne.5)then     
!HC SUM UP ALL CONDENSATE FOR CWM       
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
          IF(QQR(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=QQR(I,J,L)
          END IF
          IF(QQI(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQI(I,J,L)
          END IF
          IF(QQW(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQW(I,J,L)
          END IF
          IF(QQS(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQS(I,J,L)
          END IF
          IF(QQG(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQG(I,J,L)
          END IF 
         end do
        end do
       end do
      else
      
       VarName='CWM'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
            CWM ( i, j, l ) = dum3d ( i, j, l )
         end do
        end do
       end do 

       VarName='F_ICE_PHY'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
            F_ICE( i, j, l ) = dum3d ( i, j, l )
         end do
        end do
       end do 
       
       VarName='F_RAIN_PHY'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
            F_RAIN( i, j, l ) = dum3d ( i, j, l )
         end do
        end do
       end do 

       VarName='F_RIMEF_PHY'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM, JS,JE,LM)
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
            F_RIMEF( i, j, l ) = dum3d ( i, j, l )
         end do
        end do
       end do 

      end if
      
      IF(ICU_PHYSICS .NE. 3)THEN
      
       VarName='HTOP'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,       &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            HTOP ( i, j ) = float(LM)-dummy(i,j)+1.0
        end do
       end do
       VarName='HBOT'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,       &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            HBOT ( i, j ) = float(LM)-dummy(i,j)+1.0
        end do
       end do 
       
       VarName='CUPPT'
       call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,       &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CUPPT ( i, j ) = dummy ( i, j )
        end do
       end do
       
      END IF
      
      call getVariable(fileName,DateStr,DataHandle,'TKE',DUM3D,          &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            q2 ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do


!MEB      call getVariable(fileName,DateStr,DataHandle,'QRAIN',new)

!  get sfc pressure
      VarName='MU'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
      VarName='MUB'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY2,       &
        IM,1,JM,1,IM,JS,JE,1)
      VarName='P_TOP'
      call getVariable(fileName,DateStr,DataHandle,VarName,PT,           & 
        1,1,1,1,1,1,1,1)

         DO I=1,IM
            DO J=JS,JE
                 PINT (I,J,LM+1) = DUMMY(I,J)+DUMMY2(I,J)+PT
                 PINT (I,J,1) = PT
                 ALPINT(I,J,LM+1)=ALOG(PINT(I,J,LM+1))
                 ALPINT(I,J,1)=ALOG(PINT(I,J,1))
            ENDDO
         ENDDO
      VarName='PHB'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
      VarName='PH'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D2,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)

      print*,'finish reading geopotential'
! ph/phb are geopotential z=(ph+phb)/9.801
      DO L=1,LM+1
        DO I=1,IM
         DO J=JS,JE
          ZINT(I,J,L)=(DUM3D(I,J,L)+DUM3D2(I,J,L))/G
         ENDDO
        ENDDO
      ENDDO
      DO L=1,LM
       DO I=1,IM
        DO J=JS,JE
         ZMID(I,J,L)=(ZINT(I,J,L+1)+ZINT(I,J,L))*0.5  ! ave of z
        ENDDO
       ENDDO
      ENDDO

!!!!!!!!!!!!!
! Pyle's and Chuang's fixes for ARW SLP

        allocate(pvapor(IM,jsta_2l:jend_2u))
        allocate(pvapor_orig(IM,jsta_2l:jend_2u))
        DO J=jsta,jend
        DO I=1,IM


        pvapor(I,J)=0.
       do L=1,LM
       dz=ZINT(I,J,L)-ZINT(I,J,L+1)
       rho=PMID(I,J,L)/(RD*T(I,J,L))


        if (L .le. LM-1) then
        QMEAN=0.5*(Q(I,J,L)+Q(I,J,L+1))
        else
        QMEAN=Q(I,J,L)
        endif


       pvapor(I,J)=pvapor(I,J)+G*rho*dz*QMEAN
       enddo


! test elim
!       pvapor(I,J)=0.


        pvapor_orig(I,J)=pvapor(I,J)


      ENDDO
      ENDDO

      do L=1,405
        call exch(pvapor(1,jsta_2l))
        do J=JSTA_M,JEND_M
        do I=2,IM-1

        pvapornew=AD05*(4.*(pvapor(I-1,J)+pvapor(I+1,J)                  &  
                        +pvapor(I,J-1)+pvapor(I,J+1))                    &
                        +pvapor(I-1,J-1)+pvapor(I+1,J-1)                 &
                        +pvapor(I-1,J+1)+pvapor(I+1,J+1))                &
                        -CFT0*pvapor(I,J)

        pvapor(I,J)=pvapornew

        enddo
        enddo
        enddo   ! iteration loop

! southern boundary
        if (JS .eq. 1) then
        J=1
        do I=2,IM-1
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I,J+1)-pvapor_orig(I,J+1))
        enddo
        endif

! northern boundary

        if (JE .eq. JM) then
        J=JM
        do I=2,IM-1
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I,J-1)-pvapor_orig(I,J-1))
        enddo
        endif

! western boundary
        I=1
        do J=JS,JE
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I+1,J)-pvapor_orig(I+1,J))
        enddo

! eastern boundary
        I=IM
        do J=JS,JE
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I-1,J)-pvapor_orig(I-1,J))
        enddo

      DO J=Jsta,jend
      DO I=1,IM
              PINT(I,J,LM+1)=PINT(I,J,LM+1)+PVAPOR(I,J)
      ENDDO
      ENDDO

        write(6,*) 'surface pvapor field (post-smooth)'

        deallocate(pvapor)
        deallocate(pvapor_orig)


!!!!!!!!!!!!!


! get 3-d soil variables
      VarName='SMOIS'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &   
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
!            smc ( i, j, l ) = dum3d ( i, j, l )
! flip soil layer again because wrf soil variable vertical indexing
! is the same with eta and vertical indexing was flipped for both
! atmospheric and soil layers within getVariable
            smc ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do
      
      VarName='SH2O'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        &  
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
            sh2o ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do
      
      VarName='XICE'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
     
      do j = jsta_2l, jend_2u
        do i = 1, im
            SICE( i, j ) = dummy ( i, j )
        end do
       end do

      VarName='TSLB'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        & 
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
!            stc ( i, j, l ) = dum3d ( i, j, l )
            stc ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do

! bitmask out high, middle, and low cloud cover
       do j = jsta_2l, jend_2u
        do i = 1, im
            CFRACH ( i, j ) = SPVAL/100.
	    CFRACL ( i, j ) = SPVAL/100.
	    CFRACM ( i, j ) = SPVAL/100.
        end do
       end do

!      do l = 1, lm
!       do j = jsta_2l, jend_2u
!        do i = 1, im
!            CFR( i, j, l ) = SPVAL
!        end do
!       end do
!      end do
      
      VarName='SR'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SR( i, j ) = dummy ( i, j )
        end do
       end do
       
! WRF EM outputs 3D cloud cover now

      VarName='CLDFRA'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,        & 
         IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,VarName,DUM3D,
!     &  IM,1,JM,1,IM,JS,JE,1)
      do l=1,lm
       do j = jsta_2l, jend_2u
        do i = 1, im
!            CLDFRA( i, j ) = dummy ( i, j )
            CFR ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do 

! either assign SLDPTH to be the same as eta (which is original
! setup in WRF LSM) or extract thickness of soil layers from wrf
! output

! assign SLDPTH to be the same as eta

         SLDPTH(1)=0.10
         SLDPTH(2)=0.3
         SLDPTH(3)=0.6
         SLDPTH(4)=1.0

! or get SLDPTH from wrf output 
      call ext_ncd_get_dom_ti_integer(DataHandle  &
         ,'SF_SURFACE_PHYSICS',iSF_SURFACE_PHYSICS,1  &
         ,ioutcount, status )

      IF(iSF_SURFACE_PHYSICS==3)then ! RUC LSM
       call getVariable(fileName,DateStr,DataHandle,'ZS',SLLEVEL,  &
        NSOIL,1,1,1,NSOIL,1,1,1)
       print*,'SLLEVEL= ',(SLLEVEL(N),N=1,NSOIL)
!       SLDPTH(1)=2.*SLDPTH2(1)
!       DUM=0.
!       DO N=2,NSOIL
!         DUM=DUM+SLDPTH(N-1)
!         SLDPTH(N)=2.0*(SLDPTH2(N)-DUM)
!        print*,'N, SLDPTH for RUC= ',n,SLDPTH(N)
!       END DO
      ELSE
       call getVariable(fileName,DateStr,DataHandle,'DZS',SLDPTH2,  &
        NSOIL,1,1,1,NSOIL,1,1,1)

! if SLDPTH in wrf output is non-zero, then use it
       DUMCST=0.0
       DO N=1,NSOIL
        DUMCST=DUMCST+SLDPTH2(N)
       END DO
       IF(ABS(DUMCST-0.).GT.1.0E-2)THEN
        DO N=1,NSOIL
         SLDPTH(N)=SLDPTH2(N)
        END DO
       END IF
       print*,'SLDPTH= ',(SLDPTH(N),N=1,NSOIL)
      END IF

! get 2-d variables

      VarName='U10'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            U10 ( i, j ) = dummy( i, j )
        end do
       end do
      VarName='V10'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            V10 ( i, j ) = dummy( i, j )
        end do
       end do
!       print*,'V10 at ',ii,jj,' = ',V10(ii,jj)

       do j = jsta_2l, jend_2u
        do i = 1, im
            TH10 ( i, j ) = SPVAL
	    Q10 ( i, j ) = SPVAL
        end do
       end do

! get 2-m theta 
      VarName='TH2'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TSHLTR ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'TSHLTR at ',ii,jj,' = ',TSHLTR(ii,jj)
! get 2-m mixing ratio
      VarName='Q2'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            QSHLTR ( i, j ) = dummy ( i, j )
!HC CONVERT FROM MIXING RATIO TO SPECIFIC HUMIDITY
            QSHLTR ( i, j ) = dummy ( i, j )/(1.0+dummy ( i, j ))
        end do
       end do
!       print*,'QSHLTR at ',ii,jj,' = ',QSHLTR(ii,jj)
      VarName='SMSTAV'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SMSTAV ( i, j ) = dummy ( i, j )
        end do
       end do
       
      VarName='SMSTOT'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SMSTOT ( i, j ) = dummy ( i, j )
        end do
       end do       
             
      VarName='SFROFF' 
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SSROFF ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='UDROFF'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            BGROFF ( i, j ) = dummy ( i, j )
        end do
       end do

      VarName='SFCEVP'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SFCEVP( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'SFCEVP at ',ii,jj,' = ',SFCEVP(ii,jj) 
      
      VarName='SFCEXC'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SFCEXC ( i, j ) = dummy ( i, j )
        end do
       end do       
       
      VarName='VEGFRA'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            VEGFRC ( i, j ) = dummy ( i, j )/100.
        end do
       end do
!       print*,'VEGFRC at ',ii,jj,' = ',VEGFRC(ii,jj)
      VarName='ACSNOW'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ACSNOW ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='ACSNOM'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ACSNOM ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='CANWAT'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CMC ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='SST'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SST ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'SST at ',ii,jj,' = ',sst(ii,jj)
      VarName='THZ0'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            THZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'THZ0 at ',ii,jj,' = ',THZ0(ii,jj)
      VarName='QZ0'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'QZ0 at ',ii,jj,' = ',QZ0(ii,jj)
      VarName='UZ0'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &   
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            UZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'UZ0 at ',ii,jj,' = ',UZ0(ii,jj)
      VarName='VZ0'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            VZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'VZ0 at ',ii,jj,' = ',VZ0(ii,jj)
      VarName='QSFC'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QS ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'QS at ',ii,jj,' = ',QS(ii,jj)

      VarName='Z0'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            Z0( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'Z0 at ',ii,jj,' = ',Z0(ii,jj)

!      VarName='USTAR'
      VarName='UST'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            USTAR( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'USTAR at ',ii,jj,' = ',USTAR(ii,jj)

      VarName='AKHS'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            AKHS ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='AKMS'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            AKMS ( i, j ) = dummy ( i, j )
        end do
       end do

!
!	In my version, variable is TSK (skin temp, not skin pot temp)
!
!mp      call getVariable(fileName,DateStr,DataHandle,'THSK',DUMMY,
      VarName='TSK'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            THS ( i, j ) = dummy ( i, j ) ! this is WRONG (should be theta)
!HC CONVERT SKIN TEMPERATURE TO SKIN POTENTIAL TEMPERATURE
! CHC: deriving outgoing longwave fluxes by assuming emmissitivity=1
           RADOT ( i, j ) = DUMMY(i,j)**4.0/STBOL
           THS ( i, j ) = dummy ( i, j )                                 &
                  *(P1000/PINT(I,J,NINT(LMH(I,J))+1))**CAPA
        end do
       end do
!       print*,'THS at ',ii,jj,' = ',THS(ii,jj)

!C
!CMP
!C
!C RAINC is "ACCUMULATED TOTAL CUMULUS PRECIPITATION" 
!C RAINNC is "ACCUMULATED TOTAL GRID SCALE PRECIPITATION"

	write(6,*) 'getting RAINC'
      VarName='RAINC'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CUPREC ( i, j ) = dummy ( i, j ) * 0.001
        end do
       end do
!       print*,'CUPREC at ',ii,jj,' = ',CUPREC(ii,jj)
	write(6,*) 'getting RAINNC'
      VarName='RAINNC'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ANCPRC ( i, j ) = dummy ( i, j )* 0.001
        end do
       end do
!       print*,'ANCPRC at ',ii,jj,' = ',ANCPRC(ii,jj)
	write(6,*) 'past getting RAINNC'

       do j = jsta_2l, jend_2u
        do i = 1, im
            ACPREC(I,J)=ANCPRC(I,J)+CUPREC(I,J)
        end do
       end do  

      VarName='RAINCV'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CPRATE ( i, j ) = dummy ( i, j )* 0.001
        end do
       end do
     

      VarName='RAINNCV'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY2,       &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            prec ( i, j ) = (dummy ( i, j )+dummy2(i,j))* 0.001
        end do
       end do


      VarName='HGT'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            FIS ( i, j ) = dummy ( i, j ) * G
!            if(i.eq.80.and.j.eq.42)print*,'Debug: sample fis,zint='
!     1,dummy( i, j ),zint(i,j,lm+1)
        end do
       end do
!       print*,'FIS at ',ii,jj,' = ',FIS(ii,jj) 
	write(6,*) 'past getting of HGT'
!
      VarName='ALBEDO'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ALBEDO ( i, j ) = dummy ( i, j )
        end do
       end do
!
      VarName='GSW'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
!            RSWIN ( i, j ) = dummy ( i, j )
! HCHUANG: GSW is actually net downward shortwave in ncar wrf
             RSWIN ( i, j ) = dummy ( i, j )/(1.0-albedo(i,j))
             RSWOUT ( i, j ) = RSWIN ( i, j ) - dummy ( i, j )
        end do
       end do
! ncar wrf does not output zenith angle so make czen=czmean so that
! RSWIN can be output normally in SURFCE
       do j = jsta_2l, jend_2u
        do i = 1, im
             CZEN ( i, j ) = 1.0 
             CZMEAN ( i, j ) = CZEN ( i, j )
        end do
       end do

      VarName='GLW'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            RLWIN ( i, j ) = dummy ( i, j )
        end do
       end do
! ncar wrf does not output sigt4 so make sig4=sigma*tlmh**4
       do j = jsta_2l, jend_2u
        do i = 1, im
             TLMH=T(I,J,NINT(LMH(I,J)))
             SIGT4 ( i, j ) =  5.67E-8*TLMH*TLMH*TLMH*TLMH
        end do
       end do

! NCAR WRF does not output accumulated fluxes so set the bitmap of these fluxes to 0
      do j = jsta_2l, jend_2u
        do i = 1, im
	   RLWTOA(I,J)=SPVAL
	   RSWINC(I,J)=SPVAL
           ASWIN(I,J)=SPVAL  
	   ASWOUT(I,J)=SPVAL
	   ALWIN(I,J)=SPVAL
	   ALWOUT(I,J)=SPVAL
	   ALWTOA(I,J)=SPVAL
	   ASWTOA(I,J)=SPVAL
	   ARDLW=1.0
	   ARDSW=1.0
	   NRDLW=1
	   NRDSW=1
        end do
       end do

      VarName='TMN'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TG ( i, j ) = dummy ( i, j )
            SOILTB ( i, j ) = dummy ( i, j )
        end do
       end do

      VarName='HFX'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TWBS(I,J)= dummy ( i, j )
!            SFCSHX ( i, j ) = dummy ( i, j )
!            ASRFC=1.0
        end do
       end do
! latent heat flux
!      VarName='QFX'
      VarName='LH'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QWBS(I,J) = dummy ( i, j )
!            SFCLHX ( i, j ) = dummy ( i, j )
        end do
       end do

! ground heat fluxes       
      VarName='GRDFLX'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            GRNFLX(I,J) = dummy ( i, j )
        end do
       end do       

! NCAR WRF does not output accumulated fluxes so bitmask out these fields
      do j = jsta_2l, jend_2u
        do i = 1, im
           SFCSHX(I,J)=SPVAL  
	   SFCLHX(I,J)=SPVAL
	   SUBSHX(I,J)=SPVAL
	   SNOPCX(I,J)=SPVAL
	   SFCUVX(I,J)=SPVAL
	   POTEVP(I,J)=SPVAL
	   NCFRCV(I,J)=SPVAL
	   NCFRST(I,J)=SPVAL
	   ASRFC=1.0
	   NSRFC=1
        end do
       end do

!      VarName='WEASD'
      VarName='SNOW'  ! WRF V2 replace WEASD with SNOW
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SNO ( i, j ) = dummy ( i, j )
        end do
       end do

! snow cover
      VarName='SNOWC'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            PCTSNO ( i, j ) = dummy ( i, j )
        end do
       end do 

! GET VEGETATION TYPE

      call getIVariableN(fileName,DateStr,DataHandle,'IVGTYP',IDUMMY,    &
        IM,1,JM,1,IM,JS,JE,1)
!      print*,'sample VEG TYPE',IDUMMY(20,20)
       do j = jsta_2l, jend_2u
        do i = 1, im
            IVGTYP ( i, j ) = idummy ( i, j ) 
        end do
       end do
       
      VarName='ISLTYP'
      call getIVariableN(fileName,DateStr,DataHandle,VarName,IDUMMY,     & 
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ISLTYP ( i, j ) = idummy ( i, j ) 
        end do
       end do
       print*,'MAX ISLTYP=', maxval(idummy)

      VarName='ISLOPE'
      call getIVariableN(fileName,DateStr,DataHandle,VarName,IDUMMY,     &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ISLOPE( i, j ) = idummy ( i, j )
        end do
       end do
       

! XLAND 1 land 2 sea
      VarName='XLAND'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SM ( i, j ) = dummy ( i, j ) - 1.0
        end do
       end do

! PBL depth
      VarName='PBLH'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            PBLH ( i, j ) = dummy ( i, j )
        end do
       end do


      VarName='XLAT'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            GDLAT ( i, j ) = dummy ( i, j )
! compute F = 2*omg*sin(xlat)
            f(i,j) = 1.454441e-4*sin(gdlat(i,j)*DTR)
        end do
       end do
! pos north
!      print*,'GDLAT at ',ii,jj,' = ',GDLAT(ii,jj)
      print*,'read past GDLAT'
      VarName='XLONG'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,         &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            GDLON ( i, j ) = dummy ( i, j )
!            if(abs(GDLAT(i,j)-20.0).lt.0.5 .and. abs(GDLON(I,J)
!     1      +157.0).lt.5.)print*
!     2      ,'Debug:I,J,GDLON,GDLAT,SM,HGT,psfc= ',i,j,GDLON(i,j)
!     3      ,GDLAT(i,j),SM(i,j),FIS(i,j)/G,PINT(I,j,lm+1)
        end do
       end do
!       print*,'GDLON at ',ii,jj,' = ',GDLON(ii,jj)
       print*,'read past GDLON' 
! pos east
       call collect_loc(gdlat,dummy)
       if(me.eq.0)then
        latstart=nint(dummy(1,1)*1000.)
        latlast=nint(dummy(im,jm)*1000.)
!        print*,'LL corner from model output= ',dummy(1,1)
!        print*,'LR corner from model output= ',dummy(im,1)
!        print*,'UL corner from model output= ',dummy(1,jm)
!        print*,'UR corner from model output= ',dummy(im,jm)
       end if
       write(6,*) 'laststart,latlast B calling bcast= ',latstart,latlast
       call mpi_bcast(latstart,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       call mpi_bcast(latlast,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       write(6,*) 'laststart,latlast A calling bcast= ',latstart,latlast
       call collect_loc(gdlon,dummy)
       if(me.eq.0)then
        lonstart=nint(dummy(1,1)*1000.)
        lonlast=nint(dummy(im,jm)*1000.)
!        print*,'LL corner from model output= ',dummy(1,1)
!        print*,'LR corner from model output= ',dummy(im,1)
!        print*,'UL corner from model output= ',dummy(1,jm)
!        print*,'UR corner from model output= ',dummy(im,jm)
       end if
       write(6,*)'lonstart,lonlast B calling bcast=',lonstart,lonlast
       call mpi_bcast(lonstart,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       call mpi_bcast(lonlast,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       write(6,*)'lonstart,lonlast A calling bcast= ',lonstart,lonlast
!
! obtain map scale factor
!      VarName='msft'
      VarName='MAPFAC_M'
      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,        &  
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            MSFT ( i, j ) = dummy ( i, j ) 
        end do
       end do

! physics calling frequency
      VarName='STEPBL'
      call getIVariableN(fileName,DateStr,DataHandle,VarName,NPHS,       &
        1,1,1,1,1,1,1,1)
     

!        ncdump -h


!!
!! 
!!
        write(6,*) 'filename in INITPOST=', filename,' is'

!	status=nf_open(filename,NF_NOWRITE,ncid)
!	        write(6,*) 'returned ncid= ', ncid
!        status=nf_get_att_real(ncid,varid,'DX',tmp)
!	dxval=int(tmp)
!        status=nf_get_att_real(ncid,varid,'DY',tmp)
!	dyval=int(tmp)
!        status=nf_get_att_real(ncid,varid,'CEN_LAT',tmp)
!	cenlat=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'CEN_LON',tmp)
!	cenlon=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'TRUELAT1',tmp)
!	truelat1=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'TRUELAT2',tmp)
!	truelat2=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'MAP_PROJ',tmp)
!        maptype=int(tmp)
!	status=nf_close(ncid)

!	dxval=30000.
! 	dyval=30000.
!
!        write(6,*) 'dxval= ', dxval
!        write(6,*) 'dyval= ', dyval
!        write(6,*) 'cenlat= ', cenlat
!        write(6,*) 'cenlon= ', cenlon
!        write(6,*) 'truelat1= ', truelat1
!        write(6,*) 'truelat2= ', truelat2
!        write(6,*) 'maptype is ', maptype
!
        call ext_ncd_get_dom_ti_real(DataHandle,'DX',tmp,                &      
          1,ioutcount,istatus)
        dxval=nint(tmp)
        write(6,*) 'dxval= ', dxval
        call ext_ncd_get_dom_ti_real(DataHandle,'DY',tmp,                &
          1,ioutcount,istatus)
        dyval=nint(tmp)
        write(6,*) 'dyval= ', dyval
        call ext_ncd_get_dom_ti_real(DataHandle,'CEN_LAT',tmp,           &
          1,ioutcount,istatus)
        cenlat=nint(1000.*tmp)
        write(6,*) 'cenlat= ', cenlat
        call ext_ncd_get_dom_ti_real(DataHandle,'CEN_LON',tmp,           &
          1,ioutcount,istatus)
        cenlon=nint(1000.*tmp)
        write(6,*) 'cenlon= ', cenlon
        call ext_ncd_get_dom_ti_real(DataHandle,'TRUELAT1',tmp,          &
          1,ioutcount,istatus)
        truelat1=nint(1000.*tmp)
        write(6,*) 'truelat1= ', truelat1
        call ext_ncd_get_dom_ti_real(DataHandle,'TRUELAT2',tmp,          &
          1,ioutcount,istatus)
        truelat2=nint(1000.*tmp)
        write(6,*) 'truelat2= ', truelat2
	call ext_ncd_get_dom_ti_real(DataHandle,'STAND_LON',tmp,         &
          1,ioutcount,istatus)
        STANDLON=nint(1000.*tmp)
        write(6,*) 'STANDLON= ', STANDLON
        call ext_ncd_get_dom_ti_integer(DataHandle,'MAP_PROJ',itmp,      &
          1,ioutcount,istatus)
        maptype=itmp
        write(6,*) 'maptype is ', maptype

!MEB not sure how to get these 
       do j = jsta_2l, jend_2u
        do i = 1, im
            DX ( i, j ) = dxval/MSFT(I,J)  
            DY ( i, j ) = dyval/MSFT(I,J)  
        end do
       end do
       ii=im/2
       jj=(jend+jsta)/2
!       print*,'sample dx,dy,msft=',ii,jj,dx(ii,jj),dy(ii,jj)
!     + ,msft(ii,jj)
! generate look up table for lifted parcel calculations

      THL=210.
      PLQ=70000.

      CALL TABLE(PTBL,TTBL,PT,                                           &  
                RDQ,RDTH,RDP,RDTHE,PL,THL,QS0,SQS,STHE,THE0)

      CALL TABLEQ(TTBLQ,RDPQ,RDTHEQ,PLQ,THL,STHEQ,THE0Q)

!     
!     
      IF(ME.EQ.0)THEN
        WRITE(6,*)'  SPL (POSTED PRESSURE LEVELS) BELOW: '
        WRITE(6,51) (SPL(L),L=1,LSM)
   50   FORMAT(14(F4.1,1X))
   51   FORMAT(8(F8.1,1X))
      ENDIF
!     
!     COMPUTE DERIVED TIME STEPPING CONSTANTS.
!
!need to get DT
      call ext_ncd_get_dom_ti_real(DataHandle,'DT',tmp,1,ioutcount,istatus)
      DT=tmp
      print*,'DT= ',DT
      
       
!      DT = 120. !MEB need to get DT
      NPHS = 1  !CHUANG SET IT TO 1 BECAUSE ALL THE INST PRECIP ARE ACCUMULATED 1 TIME STEP
      DTQ2 = DT * NPHS  !MEB need to get physics DT
      TSPH = 3600./DT   !MEB need to get DT
! Randomly specify accumulation period because WRF EM does not
! output accumulation fluxes yet and accumulated fluxes are bit
! masked out

      TSRFC=1.0
      TRDLW=1.0
      TRDSW=1.0
      THEAT=1.0
      TCLOD=1.0
      TPREC=float(ifhr)  ! WRF EM does not empty precip buket at all
!      TSRFC=float(NSRFC)/TSPH
!      TRDLW=float(NRDLW)/TSPH
!      TRDSW=float(NRDSW)/TSPH
!      THEAT=float(NHEAT)/TSPH
!      TCLOD=float(NCLOD)/TSPH
!      TPREC=float(NPREC)/TSPH
      print*,'TSRFC TRDLW TRDSW= ',TSRFC, TRDLW, TRDSW
!MEB need to get DT

!how am i going to get this information?
!      NPREC  = INT(TPREC *TSPH+D50)
!      NHEAT  = INT(THEAT *TSPH+D50)
!      NCLOD  = INT(TCLOD *TSPH+D50)
!      NRDSW  = INT(TRDSW *TSPH+D50)
!      NRDLW  = INT(TRDLW *TSPH+D50)
!      NSRFC  = INT(TSRFC *TSPH+D50)
!how am i going to get this information?
!     
!     IF(ME.EQ.0)THEN
!       WRITE(6,*)' '
!       WRITE(6,*)'DERIVED TIME STEPPING CONSTANTS'
!       WRITE(6,*)' NPREC,NHEAT,NSRFC :  ',NPREC,NHEAT,NSRFC
!       WRITE(6,*)' NCLOD,NRDSW,NRDLW :  ',NCLOD,NRDSW,NRDLW
!     ENDIF
!

!      VarName='RAINCV'
!      call getVariable(fileName,DateStr,DataHandle,VarName,DUMMY,
!     &  IM,1,JM,1,IM,JS,JE,1)
!       do j = jsta_2l, jend_2u
!        do i = 1, im
!            CUPPT ( i, j ) = dummy ( i, j )* 0.001*(TRDLW*3600.)	    
!        end do
!       end do


      
!     COMPUTE DERIVED MAP OUTPUT CONSTANTS.
      DO L = 1,LSM
         ALSL(L) = ALOG(SPL(L))
      END DO
! close up shop
       call ext_ncd_ioclose ( DataHandle, Status )
!
!HC WRITE IGDS OUT FOR WEIGHTMAKER TO READ IN AS KGDSIN
        if(me.eq.0)then
        print*,'writing out igds'
        igdout=110
!        open(igdout,file='griddef.out',form='unformatted'
!     +  ,status='unknown')
        if(maptype .eq. 1)THEN  ! Lambert conformal
          WRITE(igdout)3
          WRITE(6,*)'igd(1)=',3
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
!          WRITE(igdout)CENLON
          WRITE(igdout)STANDLON
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)TRUELAT2
          WRITE(igdout)TRUELAT1
          WRITE(igdout)255
        ELSE IF(MAPTYPE .EQ. 2)THEN  !Polar stereographic
          WRITE(igdout)5
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
          WRITE(igdout)CENLON
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)TRUELAT2  !Assume projection at +-90
          WRITE(igdout)TRUELAT1
          WRITE(igdout)255
        ELSE IF(MAPTYPE .EQ. 3)THEN  !Mercator
          WRITE(igdout)1
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
          WRITE(igdout)latlast
          WRITE(igdout)lonlast
          WRITE(igdout)TRUELAT1
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)255
         END IF

! following for hurricane wrf post
     
          open(10,file='copygb_hwrf.txt',form='formatted',               & 
              status='unknown')
           idxvald=abs(LONLAST-LONSTART)/(im-2)
           idyvald=abs(LATLAST-LATSTART)/(jm-2)
           print*,'dxval,dyval in degree',dxval/107000.,dyval/107000.
	   print*,'idxvald,idyvald,LATSTART,LONSTART,LATLAST,LONLAST= ', &
             idxvald,idyvald,LATSTART,LONSTART,LATLAST,LONLAST
           write(10,1010) IM-1,JM-1,LATSTART,LONSTART,LATLAST,LONLAST,   &
                 idxvald,idyvald
                                                                                             
1010      format('255 0 ',2(I3,x),I6,x,I7,x,'136 ',I6,x,I7,x,            &
                 2(I6,x),'64')
          close (10)
        end if
!     
!

      RETURN
      END
