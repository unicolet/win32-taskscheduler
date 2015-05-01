#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "TaskScheduler.h"

MODULE = Win32::TaskScheduler		PACKAGE = Win32::TaskScheduler

SV*
New(SV* self)
	INIT:
	HRESULT hr;
	HV *b_hash;
	SV *pSvBlessed = NULL;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:

	b_hash=newHV();

	hr = ERROR_SUCCESS;
	hr = CoInitialize( NULL );

	if ( SUCCEEDED( hr ) || hr == RPC_E_CHANGED_MODE || hr == S_FALSE)
	{
#if TSK_DEBUG
		printf("\t\tDEBUG: successfully initialized COM\n");
#endif
	    hr = CoCreateInstance( (CLSID*)&CLSID_CTaskScheduler,
	                           NULL,
	                           CLSCTX_INPROC_SERVER,
	                           (IID*)&IID_ITaskScheduler,
	                           (void **) &taskSched );
	    if( FAILED( hr ) )
	    {
	        CoUninitialize();
	    } else {
#if TSK_DEBUG
		printf("\t\tDEBUG: Successfully initialized taskSched: %d\n",taskSched);
#endif
		if(DataToBlessedHash(newRV_noinc((SV*)b_hash),taskSched,activeTask))
			{
			pSvBlessed = sv_bless( newRV_noinc( (SV*) b_hash ), gv_stashpv( "Win32::TaskScheduler", TRUE ) );

			RETVAL=pSvBlessed;
#if TSK_DEBUG
		printf("\t\tDEBUG: Successfully blessed hash: %d\n",taskSched);
#endif
			}

		}
	}
	OUTPUT:
		RETVAL


void
End(SV* self)
	INIT:
	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask != NULL) ITaskScheduler_Release(activeTask);
	if(taskSched != NULL) ITask_Release(taskSched);
	CoUninitialize();
	DataToBlessedHash(self,NULL,NULL);

void
Enum(SV* self)
	INIT:
	IEnumWorkItems *pIEnum;
	LPWSTR *lpwszNames;
	DWORD dwFetchedTasks;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	PPCODE:
		hr = ERROR_SUCCESS;
		dwFetchedTasks = 0;

		DataFromBlessedHash(self,&taskSched,&activeTask);

		if (taskSched == NULL)
			{
			wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
			XSRETURN_UNDEF;
			}
		hr = ITaskScheduler_Enum(taskSched, &pIEnum);

		if (FAILED(hr))
		{
		  wprintf(L"Win32::TaskScheduler:Failed to initialize an Enumeration obj.\n");
		  XSRETURN_UNDEF;
		}

		while (SUCCEEDED(IEnumWorkItems_Next(pIEnum, TASKS_TO_RETRIEVE,&lpwszNames,&dwFetchedTasks)) && (dwFetchedTasks != 0))
		{
		  while (dwFetchedTasks)
		  {
			 char *tmp=_tochar(lpwszNames[--dwFetchedTasks],FALSE);
			 PUSHs(sv_2mortal(newSVpv(tmp,strlen(tmp))));
			 CoTaskMemFree(lpwszNames[dwFetchedTasks]);
		  }
		  CoTaskMemFree(lpwszNames);
		}

		IEnumWorkItems_Release(pIEnum);


int
Activate(SV* self,char *jobName)
	INIT:
	HRESULT hr;
	LPCWSTR tsk;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:

	DataFromBlessedHash(self,&taskSched,&activeTask);

	if (activeTask != NULL)
		{
			ITask_Release(activeTask);
			activeTask=NULL;
		}

	tsk=_towchar(jobName,FALSE);
	hr = ITaskScheduler_Activate(taskSched, tsk,
                      	IID_ITask,
                      	(IUnknown**) &activeTask);

	if (FAILED(hr))
	{
		activeTask=NULL;
		RETVAL=0;
	} else {
		RETVAL=1;
	}

## save pointer info to blessed hash
	DataToBlessedHash(self,taskSched,activeTask);

	OUTPUT:
	RETVAL

int
SetTargetComputer(SV* self,char* host)
	INIT:
	HRESULT hr;
	LPCWSTR hst;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:

	DataFromBlessedHash(self,&taskSched,&activeTask);

	if (taskSched == NULL)
		{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
		}
	hst=_towchar(host,FALSE);

    hr = ITaskScheduler_SetTargetComputer(taskSched, hst);
    if (FAILED(hr))
    {
		RETVAL=0;
    } else {
		RETVAL=1;
	}

	OUTPUT:
	RETVAL

char*
GetAccountInformation(SV* self)
	INIT:
	LPWSTR usr;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}
	if(activeTask == NULL)
	{
		XSRETURN_UNDEF;
	}

	hr = ITask_GetAccountInformation(activeTask, &usr);
	if(SUCCEEDED(hr) && hr != SCHED_E_NO_SECURITY_SERVICES)
	{
		char *tmp=_tochar(usr,FALSE);
		RETVAL=tmp;
	} else {
		XSRETURN_UNDEF;
	}
	CoTaskMemFree(usr);

	OUTPUT:
	RETVAL

int
SetAccountInformation(SV* self,char* usr,char* pwd)
	INIT:
	LPCWSTR user, password;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	//Based on patch contributed by Andreas Hartmann
	if ((strcmp (usr,"") == 0) && ( pwd == NULL || (strcmp (pwd,"") == 0)) )
	{
		hr = ITask_SetAccountInformation(activeTask, L"",NULL); // run as system-Account
	}
	else
	{
		user=_towchar(usr,FALSE);
		password=_towchar(pwd,FALSE);
		hr = ITask_SetAccountInformation(activeTask,user,password);
	}
	
	switch(hr) {
		case S_OK : { RETVAL=1; break; }
		case E_ACCESSDENIED : { RETVAL=0; break; }
		case E_INVALIDARG : { RETVAL=-1; break; }
		case E_OUTOFMEMORY : { RETVAL=-2; break; }
		case SCHED_E_NO_SECURITY_SERVICES : { RETVAL=-3; break; }
		default : { RETVAL=-4; break; }
	}

	OUTPUT:
	RETVAL

int
Save(SV* self)
	INIT:
	IPersistFile *pIPersistFile;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr = ITask_QueryInterface(activeTask, IID_IPersistFile,
	                             	(void **)&pIPersistFile);
	if(SUCCEEDED(hr))
	{
		hr = IPersistFile_Save(pIPersistFile, NULL,
	                             TRUE);
		if(FAILED(hr))
		{
			RETVAL=0;
		} else {
			RETVAL=1;
		}
		IPersistFile_Release(pIPersistFile);
	} else {
		RETVAL=0;
	}

	ITask_Release(activeTask);
	activeTask=NULL;

	DataToBlessedHash(self,taskSched,activeTask);

	OUTPUT:
	RETVAL

char*
GetApplicationName(SV* self)
	INIT:
	LPWSTR ApplicationName;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if (activeTask==NULL || taskSched == NULL) XSRETURN_UNDEF;

	hr = ITask_GetApplicationName(activeTask, &ApplicationName);

	if (FAILED(hr)) XSRETURN_UNDEF;

	char *tmp=_tochar(ApplicationName,FALSE);
	RETVAL=tmp;

	CoTaskMemFree(ApplicationName);

	OUTPUT:
	RETVAL

int
SetApplicationName(SV* self,char* app)
	INIT:
	LPCWSTR application;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	application=_towchar(app,FALSE);
#if TSK_DEBUG
		printf("\tDEBUG: entered SetApplicationName\n");
#endif
	if(activeTask == NULL || taskSched == NULL)
	{
#if TSK_DEBUG
		printf("\t\tDEBUG: NULL pointer; activeTask=%d taskSched=%d\n",activeTask,taskSched);
#endif
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr = ITask_SetApplicationName(activeTask, application);

	if(FAILED(hr))
		RETVAL=0;
	else
		RETVAL=1;
	OUTPUT:
		RETVAL


char*
GetParameters(SV* self)
	INIT:
	LPWSTR Parameters;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}

	hr = ITask_GetParameters(activeTask, &Parameters);
	if(FAILED(hr)) XSRETURN_UNDEF;

	char *tmp=_tochar(Parameters,FALSE);
	RETVAL=tmp;

	CoTaskMemFree(Parameters);
	OUTPUT:
	RETVAL

int
SetParameters(SV* self,char* param)
	INIT:
	LPWSTR Parameters;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	Parameters=_towchar(param,FALSE);

	hr = ITask_SetParameters(activeTask, Parameters);

	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

char*
GetWorkingDirectory(SV* self)
	INIT:
	LPWSTR Directory;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}

	hr = ITask_GetWorkingDirectory(activeTask, &Directory);
	if(FAILED(hr)) XSRETURN_UNDEF;

	char *tmp=_tochar(Directory,FALSE);
	RETVAL=tmp;

	CoTaskMemFree(Directory);
	OUTPUT:
	RETVAL

int
SetWorkingDirectory(SV* self,char* dir)
	INIT:
	LPWSTR Directory;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	Directory=_towchar(dir,FALSE);

	hr = ITask_SetWorkingDirectory(activeTask, Directory);

	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

int
Delete(SV* self,char* jobname)
	INIT:
	LPCWSTR job;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	job=_towchar(jobname,FALSE);
	hr=ITaskScheduler_Delete(taskSched, job);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

int
GetPriority(SV* self,SV* pri)
	INIT:
	HRESULT hr;
	DWORD priority;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetPriority(activeTask, &priority);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	sv_setnv(pri,(double)priority);

	OUTPUT:
	RETVAL

int
SetPriority(SV* self,double pri)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_SetPriority(activeTask,(DWORD)pri);
	if(FAILED(hr))
		{
		RETVAL=0;
		}
	else {
		RETVAL=1;
	}
	OUTPUT:
	RETVAL

int
NewWorkItem(SV* self,char* name,SV* strigger)
	INIT:
	HRESULT hr;
	LPCWSTR pwszTaskName;
	ITask *pITask;

	ITaskTrigger *pITaskTrigger;
	WORD piNewTrigger,tType;
	TASK_TRIGGER pTrigger;
	IPersistFile *pIPersistFile;

	SV** rtmp;
	SV* tmp;
	HV* htmp, *trigger;

	int i;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}
#if TSK_DEBUG
		printf("\tDEBUG: entered NewWorkItem\n");
#endif

	pwszTaskName=_towchar(name,FALSE);

	if(activeTask!=NULL) { ITask_Release(activeTask); activeTask=NULL; }

## we must save, otherwise if we had an error
## the hash woul still point to the old task, if any!
	DataToBlessedHash(self,taskSched,activeTask);

	hr = ITaskScheduler_NewWorkItem(taskSched, pwszTaskName,
	                       		CLSID_CTask,
	                       		IID_ITask,
	                       		(IUnknown**)&pITask);

	if(FAILED(hr))
		{
		RETVAL=0;
		XSRETURN_IV(0);
		}
	else {
#if TSK_DEBUG
		printf("\t\tDEBUG: successfully created NewWorkItem\n");
#endif

		activeTask=pITask;

## now we can start setting trigger
## the user passed something in...
		if(SvROK(strigger))
			{
## create trigger object..
			hr=ITask_CreateTrigger(activeTask,&piNewTrigger,&pITaskTrigger);
            if(FAILED(hr)) {XSRETURN_IV(0);}
            ZeroMemory(&pTrigger, sizeof(TASK_TRIGGER));

		 	if ( SvROK(strigger) && ( SvTYPE(SvRV(strigger)) == SVt_PVHV ) )
		 	{
		 		trigger=(HV*)SvRV(strigger);
		 	} else { XSRETURN_IV(0); }
#if TSK_DEBUG
		printf("\t\tDEBUG: successfully dereferenced strigger and CreateTrigger\n");
#endif
			pTrigger.cbTriggerSize = sizeof (TASK_TRIGGER);

			if((i=IntFromHash(trigger,MY_BeginYear))) pTrigger.wBeginYear=i;
			if((i=IntFromHash(trigger,MY_BeginMonth))) pTrigger.wBeginMonth=i;
			if((i=IntFromHash(trigger,MY_BeginDay))) pTrigger.wBeginDay=i;
			if((i=IntFromHash(trigger,MY_EndYear))) pTrigger.wEndYear=i;
			if((i=IntFromHash(trigger,MY_EndMonth))) pTrigger.wEndMonth=i;
			if((i=IntFromHash(trigger,MY_EndDay))) pTrigger.wEndDay=i;
			if((i=IntFromHash(trigger,MY_StartHour))) pTrigger.wStartHour=i;
			if((i=IntFromHash(trigger,MY_StartMinute))) pTrigger.wStartMinute=i;
			if((i=IntFromHash(trigger,MY_MinutesDuration))) pTrigger.MinutesDuration=i;
			if((i=IntFromHash(trigger,MY_MinutesInterval))) pTrigger.MinutesInterval=i;
			pTrigger.TriggerType=(TASK_TRIGGER_TYPE)IntFromHash(trigger,MY_TriggerType);
			if((i=IntFromHash(trigger,MY_RandomMinutesInterval))) pTrigger.wRandomMinutesInterval=i;
			if((i=IntFromHash(trigger,MY_Flags))) pTrigger.rgFlags=i;
#if TSK_DEBUG
			printf("Task will start at:%d/%d/%d %d:%d and will be sched as %d with flags %d\n",
					pTrigger.wBeginYear,
					pTrigger.wBeginMonth,
					pTrigger.wBeginDay,
					pTrigger.wStartHour,
					pTrigger.wStartMinute,
					pTrigger.TriggerType,
					pTrigger.rgFlags);
#endif
			switch(pTrigger.TriggerType) {
			case TASK_TIME_TRIGGER_ONCE              : { break; }
			case TASK_TIME_TRIGGER_DAILY             : {
														htmp=HashFromHash(trigger,MY_Type);
														if(htmp)
															{
															if((i=IntFromHash(htmp,MY_DaysInterval))) pTrigger.Type.Daily.DaysInterval = i;
															}
														break;
													   }
			case TASK_TIME_TRIGGER_WEEKLY            : {
														htmp=HashFromHash(trigger,MY_Type);
														if(htmp)
															{
															if((i=IntFromHash(htmp,MY_WeeksInterval))) pTrigger.Type.Weekly.WeeksInterval = i;
															if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.Weekly.rgfDaysOfTheWeek = i;
															}
														break;
													   }
			case TASK_TIME_TRIGGER_MONTHLYDATE       : {
														htmp=HashFromHash(trigger,MY_Type);
														if(htmp)
															{
															if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDate.rgfMonths  = i;
#if TSK_DEBUG
		printf("\t\tDEBUG: MONTHLYDATE, Months=%d\n",i);
#endif

															if((i=IntFromHash(htmp,MY_Days))) pTrigger.Type.MonthlyDate.rgfDays  = humanDaysToBitField(i);
#if TSK_DEBUG
		printf("\t\tDEBUG: MONTHLYDATE, Days=%d\n",i);
#endif
															}
														break;
													   }
			case TASK_TIME_TRIGGER_MONTHLYDOW        : {
														htmp=HashFromHash(trigger,MY_Type);
														if(htmp)
															{
															if((i=IntFromHash(htmp,MY_WhichWeek))) pTrigger.Type.MonthlyDOW.wWhichWeek = i;
															if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.MonthlyDOW.rgfDaysOfTheWeek  = i;
															if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDOW.rgfMonths  = i;
															}
														break;
													   }
			case TASK_EVENT_TRIGGER_ON_IDLE          : { break; }
			case TASK_EVENT_TRIGGER_AT_LOGON         : { break; }
			case TASK_EVENT_TRIGGER_AT_SYSTEMSTART   : { break; }
			default : { RETVAL=-1; XSRETURN_IV(-1); }
			}
#if TSK_DEBUG
		printf("\t\tDEBUG: successfully parsed hash into structure\n");
#endif
			hr = ITaskTrigger_SetTrigger(pITaskTrigger, &pTrigger);
			if(FAILED(hr))
				{
				RETVAL=-1;
				XSRETURN_IV(-1);
				}
#if TSK_DEBUG
		printf("\t\tDEBUG: successfully called SetTrigger\n");
#endif
			ITaskTrigger_Release(pITaskTrigger);
			RETVAL=1;
			DataToBlessedHash(self,taskSched,activeTask);
#if TSK_DEBUG
		printf("\t\tDEBUG: returning success(1) from NewWorkItem\n");
#endif
			XSRETURN_IV(1);
			}
	}

int
GetTriggerCount(SV* self)
	INIT:
	HRESULT hr;
	WORD TriggerCount;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(-1);
	}

	hr=ITask_GetTriggerCount(activeTask,&TriggerCount);
	if(FAILED(hr))
		RETVAL=-1;
	else RETVAL=(int)TriggerCount;

	OUTPUT:
	RETVAL


char*
GetTriggerString(SV* self,int TriggerIndex)
	INIT:
	HRESULT hr;
	LPWSTR triggerStr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_NO;
	}

	hr=ITask_GetTriggerString(activeTask,TriggerIndex,&triggerStr);
	if (FAILED(hr))
		{
			RETVAL="";
		}
	else {
		char *tmp=_tochar(triggerStr,FALSE);
		RETVAL=tmp;
	}

	CoTaskMemFree(triggerStr);
	OUTPUT:
	RETVAL

int
DeleteTrigger(SV* self,int triggerIndex)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_DeleteTrigger(activeTask,(WORD)triggerIndex);
	if (FAILED(hr))
		{
			RETVAL=0;
		}
	else {
		RETVAL=1;
	}
	OUTPUT:
	RETVAL

int
GetTrigger(SV* self,int triggerIndex,SV* hashTrigger)
	INIT:
	HRESULT hr;
	HV *hTrigger, *htmp;

	ITaskTrigger *pITaskTrigger;
	WORD piNewTrigger,tType;
	TASK_TRIGGER pTrigger;

	SV* ok;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr = ITask_GetTrigger(activeTask,triggerIndex,&pITaskTrigger);
	if(FAILED(hr)) XSRETURN_IV(0);

## now we try to get the trigger structure from the TaskTrigger object
##
	ZeroMemory(&pTrigger, sizeof(TASK_TRIGGER));
	pTrigger.cbTriggerSize = sizeof (TASK_TRIGGER);

	hr = ITaskTrigger_GetTrigger(pITaskTrigger, &pTrigger);
	if(FAILED(hr)) { ITaskTrigger_Release(pITaskTrigger); XSRETURN_IV(0); }

 	if ( SvROK(hashTrigger) && ( SvTYPE(SvRV(hashTrigger)) == SVt_PVHV ) )
 	{
 		hTrigger=(HV*)SvRV(hashTrigger);
 	}

	IntToHash(hTrigger,MY_BeginYear,pTrigger.wBeginYear);
	IntToHash(hTrigger,MY_BeginMonth,pTrigger.wBeginMonth);
	IntToHash(hTrigger,MY_BeginDay,pTrigger.wBeginDay);
	IntToHash(hTrigger,MY_EndYear,pTrigger.wEndYear);
	IntToHash(hTrigger,MY_EndMonth,pTrigger.wEndMonth);
	IntToHash(hTrigger,MY_EndDay,pTrigger.wEndDay);
	IntToHash(hTrigger,MY_StartHour,pTrigger.wStartHour);
	IntToHash(hTrigger,MY_StartMinute,pTrigger.wStartMinute);
	IntToHash(hTrigger,MY_MinutesDuration,pTrigger.MinutesDuration);
	IntToHash(hTrigger,MY_MinutesInterval,pTrigger.MinutesInterval);
	IntToHash(hTrigger,MY_TriggerType,pTrigger.TriggerType);
	IntToHash(hTrigger,MY_RandomMinutesInterval,pTrigger.wRandomMinutesInterval);
	IntToHash(hTrigger,MY_Flags,pTrigger.rgFlags);

	switch(pTrigger.TriggerType) {
	case TASK_TIME_TRIGGER_ONCE              : { break; }
	case TASK_TIME_TRIGGER_DAILY             : {
												htmp=newHV();
												if(htmp)
													{
													IntToHash(htmp,MY_DaysInterval,pTrigger.Type.Daily.DaysInterval);
													}
												if(HashToHash(hTrigger,MY_Type,htmp)==NULL) { ITaskTrigger_Release(pITaskTrigger); XSRETURN_NO; }
												break;
											   }
	case TASK_TIME_TRIGGER_WEEKLY            : {
												htmp=newHV();
												if(htmp)
													{
													IntToHash(htmp,MY_WeeksInterval,pTrigger.Type.Weekly.WeeksInterval);
													IntToHash(htmp,MY_DaysOfTheWeek,pTrigger.Type.Weekly.rgfDaysOfTheWeek);
													}
												if(HashToHash(hTrigger,MY_Type,htmp)==NULL) { ITaskTrigger_Release(pITaskTrigger); XSRETURN_NO; }
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDATE       : {
												htmp=newHV();
												if(htmp)
													{
													IntToHash(htmp,MY_Days,bitFieldToHumanDays(pTrigger.Type.MonthlyDate.rgfDays));
													IntToHash(htmp,MY_Months,pTrigger.Type.MonthlyDate.rgfMonths);
													}
												if(HashToHash(hTrigger,MY_Type,htmp)==NULL) { ITaskTrigger_Release(pITaskTrigger); XSRETURN_NO; }
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDOW        : {
												htmp=newHV();
												if(htmp)
													{
													IntToHash(htmp,MY_WhichWeek,pTrigger.Type.MonthlyDOW.wWhichWeek);
													IntToHash(htmp,MY_DaysOfTheWeek,pTrigger.Type.MonthlyDOW.rgfDaysOfTheWeek);
													IntToHash(htmp,MY_Months,pTrigger.Type.MonthlyDOW.rgfMonths);
													}
												if(HashToHash(hTrigger,MY_Type,htmp)==NULL) { ITaskTrigger_Release(pITaskTrigger); XSRETURN_NO; }
												break;
											   }
	case TASK_EVENT_TRIGGER_ON_IDLE          : { break; }
	case TASK_EVENT_TRIGGER_AT_LOGON         : { break; }
	case TASK_EVENT_TRIGGER_AT_SYSTEMSTART   : { break; }
	default : { XSRETURN_IV(-1); }
	}

	ITaskTrigger_Release(pITaskTrigger);
	RETVAL=1;

	OUTPUT:
	RETVAL

int SetTrigger(SV* self,int triggerIndex, SV* strigger)
	INIT:
	HRESULT hr;
	HV *trigger, *htmp;

	ITaskTrigger* pITaskTrigger;
	TASK_TRIGGER pTrigger;
	int i;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetTrigger(activeTask,triggerIndex,&pITaskTrigger);
	if (FAILED(hr)) XSRETURN_IV(0);

## now load hash into TASK_TRIGGER structure
	ZeroMemory(&pTrigger, sizeof(TASK_TRIGGER));

	if ( SvROK(strigger) && ( SvTYPE(SvRV(strigger)) == SVt_PVHV ) )
	{
		trigger=(HV*)SvRV(strigger);
	}

	pTrigger.cbTriggerSize = sizeof (TASK_TRIGGER);

	if((i=IntFromHash(trigger,MY_BeginYear))) pTrigger.wBeginYear=i;
	if((i=IntFromHash(trigger,MY_BeginMonth))) pTrigger.wBeginMonth=i;
	if((i=IntFromHash(trigger,MY_BeginDay))) pTrigger.wBeginDay=i;
	if((i=IntFromHash(trigger,MY_EndYear))) pTrigger.wEndYear=i;
	if((i=IntFromHash(trigger,MY_EndMonth))) pTrigger.wEndMonth=i;
	if((i=IntFromHash(trigger,MY_EndDay))) pTrigger.wEndDay=i;
	if((i=IntFromHash(trigger,MY_StartHour))) pTrigger.wStartHour=i;
	if((i=IntFromHash(trigger,MY_StartMinute))) pTrigger.wStartMinute=i;
	if((i=IntFromHash(trigger,MY_MinutesDuration))) pTrigger.MinutesDuration=i;
	if((i=IntFromHash(trigger,MY_MinutesInterval))) pTrigger.MinutesInterval=i;
	pTrigger.TriggerType=(TASK_TRIGGER_TYPE)IntFromHash(trigger,MY_TriggerType);
	if((i=IntFromHash(trigger,MY_RandomMinutesInterval))) pTrigger.wRandomMinutesInterval=i;
	if((i=IntFromHash(trigger,MY_Flags))) pTrigger.rgFlags=i;

	switch(pTrigger.TriggerType) {
	case TASK_TIME_TRIGGER_ONCE              : { break; }
	case TASK_TIME_TRIGGER_DAILY             : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_DaysInterval))) pTrigger.Type.Daily.DaysInterval = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_WEEKLY            : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_WeeksInterval))) pTrigger.Type.Weekly.WeeksInterval = i;
													if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.Weekly.rgfDaysOfTheWeek = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDATE       : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_Days))) pTrigger.Type.MonthlyDate.rgfDays  = humanDaysToBitField(i);
													if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDate.rgfMonths  = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDOW        : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_WhichWeek))) pTrigger.Type.MonthlyDOW.wWhichWeek = i;
													if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.MonthlyDOW.rgfDaysOfTheWeek  = i;
													if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDOW.rgfMonths  = i;
													}
												break;
											   }
	case TASK_EVENT_TRIGGER_ON_IDLE          : { break; }
	case TASK_EVENT_TRIGGER_AT_LOGON         : { break; }
	case TASK_EVENT_TRIGGER_AT_SYSTEMSTART   : { break; }
	default : { XSRETURN_IV(-1); }
	}
	hr = ITaskTrigger_SetTrigger(pITaskTrigger, &pTrigger);
	if(FAILED(hr))
		{
		XSRETURN_IV(0);
		}

	ITaskTrigger_Release(pITaskTrigger);
	RETVAL=1;

	OUTPUT:
	RETVAL

int
CreateTrigger(SV* self,SV* strigger)
	INIT:
	HRESULT hr;
	HV *trigger, *htmp;

	ITaskTrigger* pITaskTrigger;
	TASK_TRIGGER pTrigger;
	int i;
	unsigned short triggerIndex;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_CreateTrigger(activeTask,&triggerIndex,&pITaskTrigger);
	if (FAILED(hr)) XSRETURN_IV(0);

## now load hash into TASK_TRIGGER structure
	ZeroMemory(&pTrigger, sizeof(TASK_TRIGGER));

	if ( SvROK(strigger) && ( SvTYPE(SvRV(strigger)) == SVt_PVHV ) )
	{
		trigger=(HV*)SvRV(strigger);
	}

	pTrigger.cbTriggerSize = sizeof (TASK_TRIGGER);

	if((i=IntFromHash(trigger,MY_BeginYear))) pTrigger.wBeginYear=i;
	if((i=IntFromHash(trigger,MY_BeginMonth))) pTrigger.wBeginMonth=i;
	if((i=IntFromHash(trigger,MY_BeginDay))) pTrigger.wBeginDay=i;
	if((i=IntFromHash(trigger,MY_EndYear))) pTrigger.wEndYear=i;
	if((i=IntFromHash(trigger,MY_EndMonth))) pTrigger.wEndMonth=i;
	if((i=IntFromHash(trigger,MY_EndDay))) pTrigger.wEndDay=i;
	if((i=IntFromHash(trigger,MY_StartHour))) pTrigger.wStartHour=i;
	if((i=IntFromHash(trigger,MY_StartMinute))) pTrigger.wStartMinute=i;
	if((i=IntFromHash(trigger,MY_MinutesDuration))) pTrigger.MinutesDuration=i;
	if((i=IntFromHash(trigger,MY_MinutesInterval))) pTrigger.MinutesInterval=i;
	pTrigger.TriggerType=(TASK_TRIGGER_TYPE)IntFromHash(trigger,MY_TriggerType);
	if((i=IntFromHash(trigger,MY_RandomMinutesInterval))) pTrigger.wRandomMinutesInterval=i;
	if((i=IntFromHash(trigger,MY_Flags))) pTrigger.rgFlags=i;

	switch(pTrigger.TriggerType) {
	case TASK_TIME_TRIGGER_ONCE              : { break; }
	case TASK_TIME_TRIGGER_DAILY             : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_DaysInterval))) pTrigger.Type.Daily.DaysInterval = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_WEEKLY            : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_WeeksInterval))) pTrigger.Type.Weekly.WeeksInterval = i;
													if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.Weekly.rgfDaysOfTheWeek = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDATE       : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_Days))) pTrigger.Type.MonthlyDate.rgfDays  = humanDaysToBitField(i);
													if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDate.rgfMonths  = i;
													}
												break;
											   }
	case TASK_TIME_TRIGGER_MONTHLYDOW        : {
												htmp=HashFromHash(trigger,MY_Type);
												if(htmp)
													{
													if((i=IntFromHash(htmp,MY_WhichWeek))) pTrigger.Type.MonthlyDOW.wWhichWeek = i;
													if((i=IntFromHash(htmp,MY_DaysOfTheWeek))) pTrigger.Type.MonthlyDOW.rgfDaysOfTheWeek  = i;
													if((i=IntFromHash(htmp,MY_Months))) pTrigger.Type.MonthlyDOW.rgfMonths  = i;
													}
												break;
											   }
	case TASK_EVENT_TRIGGER_ON_IDLE          : { break; }
	case TASK_EVENT_TRIGGER_AT_LOGON         : { break; }
	case TASK_EVENT_TRIGGER_AT_SYSTEMSTART   : { break; }
	default : { XSRETURN_IV(-1); }
	}

	hr = ITaskTrigger_SetTrigger(pITaskTrigger, &pTrigger);
	if(FAILED(hr))
		{
		XSRETURN_IV(0);
		}

	ITaskTrigger_Release(pITaskTrigger);
	RETVAL=1;

	OUTPUT:
	RETVAL

int
SetFlags(SV* self,int flags)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_SetFlags(activeTask,(DWORD)flags);
	if (FAILED(hr)) RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

int
GetFlags(SV* self)
	INIT:
	HRESULT hr;
	DWORD flg;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetFlags(activeTask,&flg);
	if (FAILED(hr)) RETVAL=0;
	else RETVAL=flg;

	OUTPUT:
	RETVAL

int
GetExitCode(SV* self,SV* code)
	INIT:
	HRESULT hr;
	DWORD exCode;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetExitCode(activeTask,&exCode);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	sv_setiv(code,(int)exCode);

	OUTPUT:
	RETVAL

int
GetStatus(SV* self,SV* stat)
	INIT:
	HRESULT hr, st;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetStatus(activeTask,&st);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	sv_setnv(stat,(double)st);

	OUTPUT:
	RETVAL

void
GetNextRunTime(SV* self)
	INIT:
	HRESULT hr;
	SYSTEMTIME nextRun;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	PPCODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}

	hr=ITask_GetNextRunTime(activeTask,&nextRun);
	if(FAILED(hr)) { XSRETURN_UNDEF; }

	PUSHs(sv_2mortal(newSViv(nextRun.wMilliseconds)));
	PUSHs(sv_2mortal(newSViv(nextRun.wSecond)));
	PUSHs(sv_2mortal(newSViv(nextRun.wMinute)));
	PUSHs(sv_2mortal(newSViv(nextRun.wHour)));
	PUSHs(sv_2mortal(newSViv(nextRun.wDay)));
	PUSHs(sv_2mortal(newSViv(nextRun.wDayOfWeek)));
	PUSHs(sv_2mortal(newSViv(nextRun.wMonth)));
	PUSHs(sv_2mortal(newSViv(nextRun.wYear)));

int
Run(SV* self)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_Run(activeTask);
	if(FAILED(hr)) { RETVAL=0; }
	else { RETVAL=1; }

	OUTPUT:
		RETVAL

int
Terminate(SV* self)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_Terminate(activeTask);
	if(FAILED(hr)) { RETVAL=0; }
	else { RETVAL=1; }

	OUTPUT:
		RETVAL

int
SetComment(SV* self,char* comment)
	INIT:
	LPCWSTR com;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	com=_towchar(comment,FALSE);
	hr=ITask_SetComment(activeTask,com);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

char*
GetComment(SV* self)
	INIT:
	LPWSTR com;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}
	if(activeTask == NULL)
	{
		XSRETURN_UNDEF;
	}

	hr = ITask_GetComment(activeTask,&com);
	if(SUCCEEDED(hr))
	{
		char *tmp=_tochar(com,FALSE);
		RETVAL=tmp;
	} else {
		XSRETURN_UNDEF;
	}
	CoTaskMemFree(com);

	OUTPUT:
	RETVAL

int GetMaxRunTime(SV* self)
	INIT:
	HRESULT hr;
	DWORD maxRunTimeMilliSeconds;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL || activeTask == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_GetMaxRunTime(activeTask,&maxRunTimeMilliSeconds);
	if(FAILED(hr)) {
		RETVAL=0;
#if TSK_DEBUG
		printf("\t\tDEBUG: GetMaxRunTime failed\n");
#endif
	}
	else {
		RETVAL=maxRunTimeMilliSeconds;
#if TSK_DEBUG
		printf("\t\tDEBUG: GetMaxRunTime was successful\n");
#endif
	}
	OUTPUT:
	RETVAL

int SetMaxRunTime(SV* self,int maxRunTimeMilliSeconds)
	INIT:
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL || activeTask == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	hr=ITask_SetMaxRunTime(activeTask,maxRunTimeMilliSeconds);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

int
SetCreator(SV* self,char* comment)
	INIT:
	LPCWSTR com;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(taskSched == NULL || activeTask == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_IV(0);
	}

	com=_towchar(comment,FALSE);
	hr=ITask_SetCreator(activeTask,com);
	if(FAILED(hr))
		RETVAL=0;
	else RETVAL=1;

	OUTPUT:
	RETVAL

char*
GetCreator(SV* self)
	INIT:
	LPWSTR com;
	HRESULT hr;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	CODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);

	if(taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}
	if(activeTask == NULL)
	{
		XSRETURN_UNDEF;
	}

	hr = ITask_GetCreator(activeTask,&com);
	if(SUCCEEDED(hr))
	{
		char *tmp=_tochar(com,FALSE);
		RETVAL=tmp;
	} else {
		XSRETURN_UNDEF;
	}
	CoTaskMemFree(com);

	OUTPUT:
	RETVAL

void
GetMostRecentRunTime(SV* self)
	INIT:
	HRESULT hr;
	SYSTEMTIME lastRun;

	ITaskScheduler *taskSched = NULL;
	ITask *activeTask = NULL;

	PPCODE:
	DataFromBlessedHash(self,&taskSched,&activeTask);
	if(activeTask == NULL || taskSched == NULL)
	{
		wprintf(L"Win32::TaskScheduler: fatal error: null pointer, call NEW()\n");
		XSRETURN_UNDEF;
	}

	hr=ITask_GetMostRecentRunTime (activeTask,&lastRun);
	if(FAILED(hr)) { XSRETURN_UNDEF; }

	PUSHs(sv_2mortal(newSViv(lastRun.wMilliseconds)));
	PUSHs(sv_2mortal(newSViv(lastRun.wSecond)));
	PUSHs(sv_2mortal(newSViv(lastRun.wMinute)));
	PUSHs(sv_2mortal(newSViv(lastRun.wHour)));
	PUSHs(sv_2mortal(newSViv(lastRun.wDay)));
	PUSHs(sv_2mortal(newSViv(lastRun.wDayOfWeek)));
	PUSHs(sv_2mortal(newSViv(lastRun.wMonth)));
	PUSHs(sv_2mortal(newSViv(lastRun.wYear)));
