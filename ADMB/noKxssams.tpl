GLOBALS_SECTION;
  #include <math.h>
  #include <adstring.hpp>
  #include "trace.h"
  #include <fvar.hpp>
  #include <admodel.h>
  #include <df1b2fun.h>
  #include "nLogNormal.h"

  #undef PINOUT
  #define PINOUT(object) pin << "# " << #object ":\n" << setprecision(5) << object << endl;
  #undef REPORT
  #define REPORT(object) report << "# " << #object ":\n" << setprecision(5) << object << endl;

  ofstream clogf;
  const double TWO_M_PI = 2.0*M_PI;
  const double LOG_TWO_M_PI = log(TWO_M_PI);
  const double LOG_M_PI = log(M_PI);

  // ./noKxssams -noinit -nr 10 -l2 10000000  -l3 10000000 

  int fexists(const adstring& filename)
  {
    std::ifstream ifile(filename);
    if (!ifile)
       return 0;
    else
       return 1;
  }


  /*
  template <typename SCALAR> SCALAR logdnorm(const SCALAR& x, const SCALAR& mean, const SCALAR& var)
  {
     SCALAR a = 0.5*(log(TWO_M_PI*var) + square(x-mean)/var);
     return a;
  }
  template dvariable logdnorm(const dvariable& x, const dvariable& mean, const dvariable& var);
  template df1b2variable logdnorm(const df1b2variable& x, const df1b2variable& mean, const df1b2variable& var);
  */
  template <typename SCALAR> SCALAR logit(const SCALAR& p)
  {
     SCALAR a = log(p/(1.0-p));
     return a;
  }
  template double logit<double>(const double& p);
  //template dvariable logit<dvariable>(const dvariable& p);
  //template df1b2variable logit(const df1b2variable& p); 

  template <typename SCALAR> SCALAR alogit(const SCALAR& a)
  {
     SCALAR p = 1.0/(1.0+mfexp(-a));
     return p;
  }
  template double alogit<double>(const double& a);
  //template dvariable alogit<dvariable>(const dvariable& a);
  //template df1b2variable alogit(const df1b2variable& a); 

  dvector alogit(const dvector& a)
  {
     int n1 = a.indexmin();
     int n2 = a.indexmax();
     dvector p(n1,n2);
     for (int i = n1; i <= n2; i++)
        p(i) = alogit(a(i));
     return p;
  }

TOP_OF_MAIN_SECTION
  arrmblsize = 50000000;
  gradient_structure::set_CMPDIF_BUFFER_SIZE(  150000000L);
  gradient_structure::set_GRADSTACK_BUFFER_SIZE(12550000L);
  gradient_structure::set_MAX_NVAR_OFFSET(3000000);

  adstring logname(adstring(argv[0])+"_program.log");
  clogf.open(logname);
  if ( !clogf ) {
    cerr << "Cannot open program log " << logname << endl;
    ad_exit(1);
  }
  cout << "Opened program log: " << logname << endl;


DATA_SECTION
  init_int ngear;
  init_int ntime;
  init_number dt;
  number logdt;
  !!  logdt = log(dt);
  init_matrix tcatch(1,ngear,1,ntime);
  matrix obs_catch(1,ntime,1,ngear);
  !! obs_catch = trans(tcatch);

  init_matrix forcing_matrix(1,9,1,ntime);
  init_int fr;
  init_int use_mean_forcing;
  vector immigrant_biomass
  number mean_immigrant_biomass;
  number maximum_immigrant_biomass;
  !! immigrant_biomass = forcing_matrix(fr);
  !! mean_immigrant_biomass = mean(forcing_matrix(fr));
  !! maximum_immigrant_biomass = max(forcing_matrix(fr));
  !! TRACE(mean_immigrant_biomass)
  !! TRACE(maximum_immigrant_biomass)
  !! if (use_mean_forcing)
  !!    immigrant_biomass = mean_immigrant_biomass;
  !! TRACE(immigrant_biomass)

  init_int phase_T12;
  init_number init_T12;
  !! TTRACE(init_T12,phase_T12)

  init_int phase_T21;
  init_number init_T21;
  !! TTRACE(init_T21,phase_T21)

  init_int phase_r;
  init_number init_r;
  !! TTRACE(init_r,phase_r)

  init_int phase_sdlogK;
  init_number init_sdlogK;
  !!TTRACE(init_sdlogK,phase_sdlogK)

  init_int phase_sdlogF;
  init_number init_sdlogF;
  !! TTRACE(init_sdlogF,phase_sdlogF)

  init_int phase_sdlogPop;
  init_number init_sdlogPop;
  !! TTRACE(init_sdlogPop,phase_sdlogPop)

  init_int phase_sdlogYield;
  init_number init_sdlogYield;
  !! TTRACE(init_sdlogYield,phase_sdlogYield)

  init_int phase_meanProportion_local;
  init_number init_meanProportion_local;
  !! TTRACE(init_meanProportion_local,phase_meanProportion_local)

  init_int phase_sdProportion_local;
  init_number init_sdLProportion_local;
  !! TTRACE(init_sdLProportion_local,phase_sdProportion_local)

  init_int phase_qProp;
  init_number init_qProp;
  !! TTRACE(init_qProp,phase_qProp)

  init_int use_robustY;
  init_int phase_pfat;
  init_vector init_pfat(1,ngear);
  !! TTRACE(init_pfat,phase_pfat)

  int pininit;
  int lengthU;
  int utPop1;
  int utPop2;
  int utK;
  int userfun_entries;
  int status_blocks;
  ivector Fndxl;
  ivector Fndxu;
  int trace_init_pars;
  matrix residuals;
  ivector UU;

 LOCAL_CALCS;
    TRACE(ntime);
    TRACE(ngear);
    lengthU = ntime*(ngear+3);
    TRACE(lengthU)
    UU.allocate(1,lengthU);
    TTRACE(UU.indexmin(),UU.indexmax())
    for (int i = 1; i <= lengthU; i++)
       UU(i) = i;
    residuals.allocate(1,ntime,1,2*ngear+5);
    residuals.initialize();
    double ZeroCatch = 1.0; //1.0e-8;
    double logZeroCatch = log(ZeroCatch);
    TTRACE(ZeroCatch,logZeroCatch)
    int nzero = ntime;
    int ziter = 0;
    while (nzero > 0)
    {
       ziter ++;
       nzero = 0;
       for (int g = 1; g <= ngear; g++)
         for (int t = 2; t <= ntime; t++)
            if ( (obs_catch(t,g) <= 0.0) 
              && (obs_catch(t-1,g) > 0.0) && (obs_catch(t+1,g) > 0.0) )
            {
               clogf << ++nzero << " " << ziter << endl;
               obs_catch(t,g) = 0.5*(obs_catch(t-1,g) + obs_catch(t+1,g));
               clogf << nzero<< " catch for gear " << g << " at time " << t
                  << " set to " << obs_catch(t,g)  << endl;
            }
    }
    clogf << "Zero catch bridging instances: " << nzero << endl;
    obs_catch = log(obs_catch+ZeroCatch);
  
    // set up U indexing
    Fndxl.allocate(1,ntime);
    Fndxu.allocate(1,ntime);
    for (int t = 1; t<= ntime; t++)
    {
       Fndxl(t) = (t-1)*ngear+1;
       Fndxu(t) = t*ngear;
    }
    TRACE(Fndxl)
    TRACE(Fndxu)
    utPop1 = ngear*ntime;
    utPop2 = utPop1 + ntime;
    TTRACE(utPop1,utPop2)
    utK = utPop2 + ntime;
    TRACE(utK)

    //if (1) ad_exit(1);

PARAMETER_SECTION
  // transfer parameters
  init_number logT12(phase_T12);
  init_number logT21(phase_T21);

  // logistic parameters
  init_number logr(phase_r);
  init_number logsdlogK(phase_sdlogK);

  // random walk standard deviations
  init_number logsdlogF(phase_sdlogF);
  init_number logsdlogPop(phase_sdlogPop);

  // observation error standard deviations
  //init_vector logsdlogYield(1,ngear,phase_sdlogYield);
  init_number logsdlogYield(phase_sdlogYield);

  // logit transformed porportion local prior
  init_number LmeanProportion_local(phase_meanProportion_local);
  init_number logsdLProportion_local(phase_sdProportion_local);

  // non-linear term apportionment
  init_bounded_number qProp(0.0,1.0,phase_qProp);

  // robust yield likelihood proprtion contamination
  init_vector Lpfat(1,ngear,phase_pfat);

  random_effects_vector U(1,lengthU);
  //vector U(1,lengthU);

  objective_function_value nll;

PRELIMINARY_CALCS_SECTION
    userfun_entries = 0;
    status_blocks = 0;
    pininit = fexists(adstring(argv[0])+".pin");
    // set initial parameter value from data file
    TRACE(pininit)
    if (!pininit)
    {
       logT12 = log(init_T12);
       logT21 = log(init_T21);
       TTRACE(logT12,logT21)
       logr = log(init_r);
       TTRACE(logr,mfexp(logr))
       logsdlogK = log(init_sdlogK);
       TTRACE(logsdlogK,init_sdlogK)
       logsdlogF = log(init_sdlogF);
       logsdlogYield = log(init_sdlogYield);
       logsdlogPop = log(init_sdlogPop);

       LmeanProportion_local = logit((double)init_meanProportion_local);
       logsdLProportion_local = log(init_sdLProportion_local);
       TTRACE(LmeanProportion_local,logsdLProportion_local)
       //double prop = 1.0/(1.0+mfexp(-value(LmeanProportion_local)));
       double prop = alogit(value(LmeanProportion_local));
       TTRACE(LmeanProportion_local,prop)

       qProp = init_qProp;
       TTRACE(qProp,phase_qProp)

       if (!use_robustY)
       {
          phase_pfat = -1;
          init_pfat = 1e-25;
       }
       for (int g = 1; g <= ngear; g++)
       {
          Lpfat(g) = logit(init_pfat(g));
       }
       TRACE(init_pfat)
       TRACE(Lpfat)

       double K = immigrant_biomass(1);
       double logK = log(K);
       TTRACE(K,logK)
       double Pop1 = prop*K;
       double Pop2 = K-Pop1;
       TTRACE(Pop1,Pop2)
       TTRACE(log(Pop1),log(Pop2))

       //dmatrix Ferr(1,ntime,1,ngear); Ferr.fill_randn(77);
       //dmatrix logPop1Err(1,ntime,1,2); logPop1Err.fill_randn(79);
       //dmatrix logPop2Err(1,ntime,1,2); logPop2Err.fill_randn(75);
       int ut = 0;
       TRACE(ut)
       for (int t = 1; t <= ntime; t++)
       {   
          for (int g = 1; g <= ngear; g++)
          {
             U(++ut) =  -5.0; //log(0.001);
          }
       }
       TTRACE(ut,utPop1)
       for (int t = 1; t <= ntime; t++)
       {   
          U(++ut) = log(Pop1);
       }
       TTRACE(ut,utPop2)
       for (int t = 1; t <= ntime; t++)
       {   
          U(++ut) = log(Pop2);
       }
       TTRACE(ut,utK)
       for (int t = 1; t <= ntime; t++)
       {   
          U(++ut) = logK; //+0.25*(logPop2Err(t,1)+logPop2Err(t,2));
       }
       TRACE(ut)

       adstring pinname(adstring(argv[0])+".p00");
       ofstream pin(pinname);
       if (!pin)
       {
          cerr << "Error creating " << pinname << endl;
          ad_exit(1);
       }
       PINOUT(logT12)
       PINOUT(logT21)
       PINOUT(logr)
       PINOUT(logsdlogK)
       PINOUT(logsdlogF)
       PINOUT(logsdlogPop)
       PINOUT(logsdlogYield)
       PINOUT(LmeanProportion_local)
       PINOUT(logsdLProportion_local)
       PINOUT(alogit(value(Lpfat)))
       //PINOUT(U)
       pin << "# U:" << endl;
       pin << "#   F(t,g):" << endl;
       for (int tg = 1; tg <= (ntime*ngear); tg++)
           pin << " " << U(tg);
       pin << "\n#   Pop1(t):"<< endl;
       for (int tt = 1; tt <= ntime; tt++)
          pin << " " << U(utPop1+tt);
       pin << "\n#   Pop2(t):"<< endl;
       for (int tt = 1; tt <= ntime; tt++)
          pin << " " << U(utPop2+tt);
       pin << "\n#   K(t):"<< endl;
       for (int tt = 1; tt <= ntime; tt++)
          pin << " " << U(utK+tt);
       pin << endl;
       if (!pin)
       {
          cerr << "Error writing " << pinname << endl;
          ad_exit(1);
       }
       else
       {
          clogf << "Successfully created " << pinname << endl;
          cout << "Successfully created " << pinname << endl;
       }
    }
    trace_init_pars = 1;

    clogf << "\nAt end of PRELIMINARY_CALCS_SECTION:"<<endl;
    TRACE(userfun_entries)
    TTRACE(utPop1,utPop2)
    TRACE(Fndxl)
    TRACE(Fndxu)
    TRACE(lengthU)
    TRACE(logT12)
    TRACE(logT21)
    TRACE(logr)
    TRACE(logsdlogK)
    TRACE(logsdlogF)
    TRACE(logsdlogPop)
    TRACE(logsdlogYield)
    TRACE(LmeanProportion_local)
    TRACE(logsdLProportion_local)
    TRACE(alogit(value(Lpfat)))
    TRACE(U)
    TTRACE(U(utPop1+1),U(utPop2+1))
    TRACE (trace_init_pars)

    clogf << endl;

    //if (1) ad_exit(1);
  

  //RUNTIME_SETION
  // this probably isn't used ?
    //convergence_criteria .1, 1e-2


PROCEDURE_SECTION
  if (trace_init_pars)
  {
    clogf << "\nInitial step in to PROCEDURE_SECTION:" << endl;
    TRACE(userfun_entries)
    TTRACE(utPop1,utPop2)
    TRACE(Fndxl)
    TRACE(Fndxu)
    TRACE(lengthU)
    TRACE(logT12)
    TRACE(logT21)
    TRACE(logr)
    TRACE(logsdlogK)
    TRACE(logsdlogF)
    TRACE(logsdlogPop)
    TRACE(logsdlogYield)
    TRACE(LmeanProportion_local)
    TRACE(logsdLProportion_local)
    TRACE(U)
    TTRACE(U(utPop1+1),U(utPop2+1))
    TTRACE(U(Fndxl(1)),U(Fndxu(1)))
    TTRACE(U(utK+1),logsdlogK)
    trace_init_pars = 0;
    TRACE (trace_init_pars)
    clogf << endl;
    //if (1) ad_exit(1);
  }

  nll = 0.0;

  HERE
  step0(U(utPop1+1), U(utPop2+1), logsdlogPop, LmeanProportion_local,
        U(utK+1),logsdlogK,logT21);
  HERE

  for (int t = 2; t <= ntime; t++)
  {
     step(t, U(Fndxl(t-1),Fndxu(t-1)), U(Fndxl(t),Fndxu(t)), logsdlogF,
             U(utPop1+t-1), U(utPop1+t), U(utPop2+t-1), U(utPop2+t), logsdlogPop,
             U(utK+t-1),U(utK+t),logsdlogK,
             logr,logT12,logT21,LmeanProportion_local,logsdLProportion_local,qProp);
  }

  for (int t = 1; t <= ntime; t++)
  {
     obs(t,U(Fndxl(t),Fndxu(t)),U(utPop1+t-1),U(utPop1+t),
                                U(utPop2+t-1),U(utPop2+t),logsdlogYield,Lpfat);
  }

  //clogf << endl;
  ++userfun_entries;
  //TRACE(userfun_entries)
  int status_print = ntime;
  if (userfun_entries > lengthU)
     status_print = lengthU;
  if (userfun_entries % status_print == 0)
  {
     write_status(clogf);
  }

SEPARABLE_FUNCTION void step0(const dvariable& p11, const dvariable p21, const dvariable& lsdlogPop, const dvariable& LmPropL, const dvariable& logK1, const dvariable& lsdlogK, const dvariable lT21) 
  // p11 U(utPop1+t-1) log N1 at start of time step
  // p21 U(utPop2+t-1) log N2 at start of time step

  // insure initial K is near forcing biomass at time 1
  dvariable Knll = 0.0;
  dvariable T21 =mfexp(lT21);
  //dvariable PropL = alogit(LmPropL);
  dvariable PropL = 1.0/(1.0+mfexp(-LmPropL));
  dvariable p20 = T21*immigrant_biomass(1);
  dvariable p10 = -p20/(1.0-(1.0/PropL));
  TTRACE(p10,p20)
  dvariable K0 = p10 + p20;
  TRACE(K0)

  dvariable varlogK = square(mfexp(lsdlogK));
  dvariable logK0 = log(K0);
  Knll += 0.5*(log(TWO_M_PI*varlogK) + square(logK0 - logK1)/varlogK);
  nll += Knll;

  // ensure that starting population size is near K
  dvariable varlogPop = square(mfexp(lsdlogPop));
  dvariable Pnll = 0.0;
  Pnll += 0.5*(log(TWO_M_PI*varlogPop) + square(log(p10) - p11)/varlogPop);
  Pnll += 0.5*(log(TWO_M_PI*varlogPop) + square(log(p20) - p21)/varlogPop);

  nll += Pnll;



SEPARABLE_FUNCTION void step(const int t, const dvar_vector& f1, const dvar_vector& f2, const dvariable& lsdlogF, const dvariable& p11, const dvariable p12, const dvariable& p21, const dvariable p22, const dvariable& lsdlogPop,const dvariable& logK1, const dvariable& logK2, const dvariable& lsdlogK,const dvariable& lr, const dvariable& lT12, const dvariable& lT21, const dvariable& LmPropL, const dvariable& lsdLProportion_local, const dvariable& qP)
  // f1  U(Fndxl(t-1),Fndxu(t-1)) log F at start of time step
  // f2  U(Fndxl(t),Fndxu(t)      log F at end   of time step)
  // p11 U(utPop1+t-1) log N1 at start of time step
  // p12 U(utPop1+t)   log N1 at end   of time step
  // p21 U(utPop2+t-1) log N2 at start of time step
  // p22 U(utPop2+t)   log N2 at end   of time step
  // logK1 U(utK+t-1)
  // logK2 U(utK+t)

  dvariable Knll = 0.0;
  dvariable varlogK = square(mfexp(lsdlogK));
  //TTRACE(lsdlogK,varlogK)
  //TTRACE(logK1,logK2)
  Knll += 0.5*(log(TWO_M_PI*varlogK) + square(logK1 - logK2)/varlogK);
  dvariable K = mfexp(logK1);

  dvariable varlogF = square(mfexp(lsdlogF));
  dvariable varlogPop = square(mfexp(lsdlogPop));

  dvariable r = mfexp(lr);
  dvariable T12 =mfexp(lT12);
  dvariable T21 =mfexp(lT21);
  dvariable LmeanPropL = LmPropL;
  dvariable varLPropL = square(mfexp(lsdLProportion_local));
  dvar_vector ft1(1,ngear);
  dvar_vector ft2(1,ngear);
  for (int g = 1; g <= ngear; g++)
  {
     ft1(g) = f1(f1.indexmin()+g-1);
     ft2(g) = f2(f2.indexmin()+g-1);
  }

  dvariable Fnll = 0.0;
  for (int g = 1; g <= ngear; g++)
  {
     Fnll += 0.5*(log(TWO_M_PI*varlogF) + square(ft1(g)-ft2(g))/varlogF);

     if (isnan(value(Fnll)))
     {
        TTRACE(Fnll,varlogF)
        TTRACE(ft1(g),ft2(g))
        TTRACE(t,g)
        write_status(clogf);
        ad_exit(1);
     }
  } 

  dvariable sumFg = sum(mfexp(ft1)); // total fishing mortality
  dvariable q = qP;

  //       unstable for large r
  //dvariable prevN1 = mfexp(p11);
  //dvariable prevN2 = mfexp(p21);
  //dvariable nextLogN1 = p11 + dt*(r*(1.0 - prevN1/K) - sumFg - T12 - 2.0*(1.0-q)*r*prevN2/K);
  //dvariable nextLogN2 = p21 + dt*(r*(1.0 - prevN2/K) - sumFg - T12 - 2.0*q*r*prevN1/K + T21*immigrant_biomass(t)/prevN2);

  //       do multiple iterations per time step
  //       niter = 1 gives idential results to the code above
  int niter = 8;
  if (dt == 0.25)
  {
     niter = 2;
  }
  dvariable nextLogN1 = p11;
  dvariable nextLogN2 = p21;
  dvariable prevN1;
  dvariable prevN2;
  dvariable dLogN1;
  dvariable dLogN2;
  double sdt = dt/niter;
  for (int ss = 1; ss <= niter; ss++)
  {
     prevN1 = mfexp(nextLogN1);
     prevN2 = mfexp(nextLogN2);

     dLogN1 = r*(1.0 - prevN1/K) - sumFg - T12 - 2.0*(1.0-q)*r*prevN2/K;
     dLogN2 = r*(1.0 - prevN2/K) - sumFg - T12 - 2.0*q*r*prevN1/K + T21*immigrant_biomass(t)/prevN2;

     nextLogN1 = nextLogN1 + dLogN1*sdt;
     nextLogN2 = nextLogN2 + dLogN2*sdt;
  }


  //       semi-implicit approximation
  //       this doesnt work because in the initial RE step
  //       most variables to zero includeing  p11 and p21
  //       so prevN1 and precN2 = 1
  //dvariable prevN1 = mfexp(p11);
  //dvariable prevN2 = mfexp(p21);
  //dvariable dtr = dt * r;
  //dvariable nextN1 =  prevN1*(1.0+dtr-dt*(sumFg+T12)-dtr*(1.0-q)*2.0*prevN2/K)/
  //                         (1.0+dtr*prevN1/K);
  //dvariable nextN2 = (prevN2*(1.0+dtr-dt*(sumFg+T12)-dtr*q*2.0*prevN1/K)+dt*T21*immigrant_biomass(t))/
  //                         (1.0+dtr*prevN2/K);

  if ( isnan(value(nextLogN1)) || isnan(value(nextLogN2)) ||
       isinf(value(nextLogN1)) || isinf(value(nextLogN2)) )
  {
     TTRACE(prevN1,prevN2)
     TTRACE(nextLogN1,nextLogN2)
     TTRACE(r,K)
     write_status(clogf);
     ad_exit(1);
  }

  dvariable Pnll = 0.0;
  Pnll += 0.5*(log(TWO_M_PI*varlogPop) + square(p12-nextLogN1)/varlogPop);
  Pnll += 0.5*(log(TWO_M_PI*varlogPop) + square(p22-nextLogN2)/varlogPop);

 
  // proportion local prior
  dvariable PLnll = 0.0;
  dvariable LpropL = nextLogN1 - nextLogN2;
  PLnll += 0.5*(log(TWO_M_PI*varLPropL) + square(LpropL - LmeanPropL)/varLPropL);

  if (isnan(value(PLnll)))
  {
     TRACE(PLnll)
     TTRACE(nextLogN1,nextLogN2)
     TTRACE(prevN1,prevN2)
     TTRACE(r,K)
     TTRACE(LpropL,LmeanPropL)
     TRACE(varLPropL)
     write_status(clogf);
     ad_exit(1);
  }

  //clogf << t << " " << Fnll << " " <<Pnll << " " <<PLnll << " " << nll << endl;
  nll += (Fnll+Pnll+PLnll);

  

SEPARABLE_FUNCTION void obs(const int t, const dvar_vector& f,const dvariable& pop11, const dvariable& pop21,  const dvariable& pop12, const dvariable& pop22, const dvariable& logsdlogYield, const dvar_vector& Lpf)
  // f2  U(Fndxl(t),Fndxu(t)) 
  // pop11 U(utPop1+t-1)
  // pop21 U(utPop1+t)
  // pop12 U(utPop2+t-1)
  // pop22 U(utPop2+t)

  dvar_vector ft(1,ngear); ///< log fishing mortality by gear
  for (int g = 1; g <= ngear; g++)
  {
     ft(g) = f(f.indexmin()+g-1);
  }

  // sum of the average populations sizes over time step
  dvariable log_total_mean_pop;
  if (t < 2)
     log_total_mean_pop = log(mfexp(pop21) +   // population 1
                              mfexp(pop22));   // population 2
  else
     log_total_mean_pop = log( 0.5*(mfexp(pop11) + mfexp(pop21) +   // population 1
                                    mfexp(pop12) + mfexp(pop22)) ); // population 2

  dvar_vector log_pred_yield(1,ngear);
  for (int g = 1; g <= ngear; g++)
  {
     log_pred_yield(g) = logdt + ft(g) + log_total_mean_pop;
  }

  dvariable varlogYield = square(mfexp(logsdlogYield));
  dvariable Ynll = 0.0;
  for (int g = 1; g <= ngear; g++)
  {
     // observation error
     if (use_robustY == 1)  // normal + t distribution
     {
        dvariable z = square(obs_catch(t,g)-log_pred_yield(g))/varlogYield;

        dvariable norm_part = 0.5*(log(TWO_M_PI*varlogYield) + z);

        // standard Cauchy density
        dvariable fat_part = 1.0/(M_PI*(1.0 + z));
        dvariable pfat = alogit(Lpf(g));
        Ynll += log((1.0-pfat)*mfexp(norm_part) + pfat*fat_part);
     }

     // this block is incorrect and should not be used
     else if (use_robustY == 2) 
     {
        cerr << "Unsupported robustifation option: " << use_robustY << endl;
        if (1)
           ad_exit(1);
        // based on a misreading of newreg2.cpp 
        double width=3.0;
        double width2=width*width;
        const double alpha = 0.7;
        const double a2 = square(alpha);
        dvariable diff2 = square(obs_catch(t,g)-log_pred_yield(g));
        dvariable v_hat = diff2+1.0e-80;

        dvariable pcon = alogit(Lpf(g));
        dvariable b=2.*pcon/(width*sqrt(PI));  // This is the weight for the "robustifying" term

        dvariable norm_part = log(1.0-pcon)*mfexp(-diff2/(2.0*a2*v_hat));
   
        dvariable fat_part =  b/(1.+pow(diff2/(width2*a2*v_hat),2));
        Ynll += norm_part + fat_part;
     }
     else // default log-normal likelihood
     {
        Ynll += 0.5*(log(TWO_M_PI*varlogYield) + square(obs_catch(t,g)-log_pred_yield(g))/varlogYield);

        if (isnan(value(Ynll)))
        {
           TRACE(Ynll)
           TTRACE(t,g)
           write_status(clogf);
           ad_exit(1);
        }
     }
  }

  //clogf << t << " " << Ynll << " " << nll << endl;
  nll += Ynll;

  // dump stuff in "residual" matrix
  int rc = 0; // residuals column counter
  residuals(t,++rc) = value(pop21);
  residuals(t,++rc) = value(pop22);
  residuals(t,++rc) = mfexp(value(U(utK+t)));
 
  residuals(t,++rc) = mfexp(value(logT21))*immigrant_biomass(t);
  double propLa = value(pop21) - value(pop22);
  residuals(t,++rc) = alogit(propLa);

  for (int g = 1; g <= ngear; g++)
    residuals(t, ++rc) = value(ft(g));
  for (int g = 1; g <= ngear; g++)
    residuals(t, ++rc) = value(log_pred_yield(g));

FUNCTION void write_status(ofstream& s)
    double prop = alogit(value(LmeanProportion_local));
    status_blocks ++;
    s << "\n# Status after "<< userfun_entries << " PROCEDURE_SECTION entries;" << endl;
    s << "# Status block " << status_blocks << endl;
    s << "# nll = " << value(nll) << endl;
    s << "# nvar = " << initial_params::nvarcalc() << endl;
    s << "# current phase = " << current_phase() << endl;
    s << "#  logT12 = " << logT12 << " (" << active(logT12) <<")" << endl;
    s << "#  T12 = " << mfexp(logT12) << endl;
    s << "#  logT21 = " << logT21 << " (" << active(logT21) <<")" << endl;
    s << "#  T21 = " << mfexp(logT21) << endl;
    s << "# logr = " << logr << " (" << active(logr) <<")" << endl;
    s << "#    r = " << mfexp(logr) << endl;
    s << "#     logsdlogK: " << logsdlogK
             <<  " (" << active(logsdlogK) <<")" << endl;
    s << "#        sdlogK: " << mfexp(logsdlogK) << endl;
    s << "#     logsdlogF: " << logsdlogF 
             <<  " (" << active(logsdlogF) <<")" << endl;
    s << "#        sdlogF: " << mfexp(logsdlogF) << endl;
    s << "#   logsdlogPop: " << logsdlogPop
             <<  " (" << active(logsdlogPop) <<")" << endl;
    s << "#      sdlogPop: " << mfexp(logsdlogPop) << endl;
    s << "# logsdlogYield: " << logsdlogYield
             <<  " (" << active(logsdlogYield) <<")" << endl;
    s << "#    sdlogYield: " << mfexp(logsdlogYield) << endl;
    s << "# LmeanProportion_local = " << LmeanProportion_local << " (" 
                               << active(LmeanProportion_local) <<")" << endl;
    s << "#                  prop = " << prop << endl;
    s << "# logsdLProportion_local = " << logsdLProportion_local<< " (" 
                                << active(logsdLProportion_local) <<")" << endl;
    s << "#    sdLProportion_local = " << mfexp(logsdLProportion_local) << endl;
    s << "# pfat = " << alogit(value(Lpfat)) << " (" << active(Lpfat) <<")" << endl;
    s << "# qProp = " << qProp << " (" << active(qProp) << ")" << endl;
    s << "# Residuals:" << endl;
    s << "  t    pop1   pop2      K  forcing  propL";
    for (int g = 1; g <= ngear; g++)
       s << "     F" << g;
    for (int g = 1; g <= ngear; g++)
       s << "  predC" << g;
    for (int g = 1; g <= ngear; g++)
       s << "   obsC" << g;
    s << endl;
    for (int t = 1; t <= ntime; t++)
    {
       s << t << " " << residuals(t,1) << " " << residuals(t,2)
              << " " << residuals(t,3) << " " << residuals(t,4)
              << " " << residuals(t,5);
       int rc = 5;
       for (int g = 1; g <= 2*ngear; g++)
          s << " " << residuals(t,++rc);
       for (int g = 1; g <= ngear; g++)
          s << " " << obs_catch(t,g);
       s << endl;
    }



REPORT_SECTION
    write_status(clogf);
    status_blocks --;
    write_status(report);

