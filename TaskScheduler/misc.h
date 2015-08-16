#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <string.h>

int IntFromHash(HV *hash,const char* idx)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV)
			{printf("\tMISC.H: argument is not hash.\n");return NULL;}
	}

	SV **item = hash ? hv_fetch(hash, idx, strlen(idx), 0) : NULL;

	if(item && *item)
		return SvIV(*item);
	else
		return NULL;
}

IV IVFromHash(HV *hash,const char* idx)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV) {
			printf("\tMISC.H: argument is not hash.\n");
			return NULL;
		}
	}

	SV **item = hash ? hv_fetch(hash, idx, strlen(idx), 0) : NULL;

	if(item && *item)
		return SvIV(*item);
	else
		return NULL;
}

HV *HashFromHash(HV *hash,const char* idx)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV)
			return NULL;
	}

	SV **item = hash ? hv_fetch(hash, idx, strlen(idx), 0) : NULL;

	if(item && *item)
	{
		//always return a dereferenced hash...
		SV *itemDeRef = 1 && SvTYPE(*item) == SVt_RV ? SvRV(*item) : *item;

		return SvTYPE(itemDeRef) == SVt_PVHV ? (HV*)itemDeRef : NULL;
	}
	else
		return NULL;
}

int IntToHash(HV *hash,const char* idx,int val)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV)
			{printf("\tMISC.H: argument is not hash.\n");return NULL;}
	}

	SV* sVal = newSViv(val);
	SV **item = hash ? hv_store(hash, idx, strlen(idx), sVal, 0) : NULL;

	if(item && *item)
		return SvIV(*item);
	else
		return NULL;
}

void IVToHash(HV *hash,const char* idx,IV val)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV) {
			printf("\tMISC.H: argument is not hash.\n");
			return;
		}
	}

	SV* sVal = newSViv(val);
	SV **item = hash ? hv_store(hash, idx, strlen(idx), sVal, 0) : NULL;

	return;
}

HV* HashToHash(HV *hash,const char* idx,HV* subHash)
{
	if(hash)
	{
		if(SvTYPE(hash) != SVt_PVHV)
			{printf("\tMISC.H: argument is not hash.\n");return NULL;}
	}

	SV* ref = newRV_inc((SV*)subHash);
	SV **item = hash ? hv_store(hash, idx, strlen(idx), ref, 0) : NULL;

	if(item && *item)
		return (HV*)SvRV(*item);
	else
		return NULL;
}

int DataFromBlessedHash(SV* b_hash,ITaskScheduler **itask,ITask **activetask)
{
	HV* h_self = (HV*)SvRV(b_hash);

	*itask=(ITaskScheduler *)IVFromHash(h_self,"taskscheduler");
	*activetask=(ITask *)IVFromHash(h_self,"activetask");
#if TSK_DEBUG
	printf("\t\tDEBUG: DataFromBlessedHash  %d %d\n", *itask, *activetask);
#endif
	return 1;
}

int DataToBlessedHash(SV* b_hash,ITaskScheduler *itask,ITask *activetask)
{
#if TSK_DEBUG
	printf("\t\tDEBUG: DataToBlessedHash %d %d\n", itask, activetask);
	printf("sizes: %d %d\n", sizeof(itask), sizeof(IV));
#endif
	HV* h_self=(HV*) SvRV(b_hash);

	IVToHash(h_self,"taskscheduler",(IV)itask);
	IVToHash(h_self,"activetask",(IV)activetask);
	return 1;
}

IV bitFieldToHumanDays(IV day)
{
	return ((log(day)/log(2))+1);
}

IV humanDaysToBitField(IV day)
{
	return pow(2,(day-1));
}
