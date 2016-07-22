classdef soa
    %% Semiconductor Optical Amplifier
    properties
        Gain % Gain in linear units (same gain is assumed for both polarizations)
        Fn   % noise figure (dB)
        lamb % wavelength of operation (m)
        maxGaindB % maximum gain (dB)
    end
    properties (Dependent)
        GaindB
        N0 % one-sided baseband equivalent of psd of ASE noise (complex Gaussian) per polarization 
    end
    properties (Constant, Hidden)
        BWref = 12.5e9; % reference bandwidth for measuring OSNR
        h = 6.62606957e-34; % Planck
        q = 1.60217657e-19; % electron charge
        c = 299792458;      % speed of light
    end
    
    methods
        function obj = soa(GaindB, Fn, lamb, maxGaindB)
            %% Class constructor
            % maxGaindB is optional
            obj.Gain = 10^(GaindB/10);
            obj.Fn = Fn;
            obj.lamb = lamb;
                        
            if exist('maxGaindB', 'var')
                obj.maxGaindB = maxGaindB;
            else
                obj.maxGaindB = Inf;
            end
        end
        
        function SOAtable = summary(self)
            %% Generate table summarizing class values
            disp('SOA class parameters summary:')
            rows = {'Gain'; 'Noise Figure'; 'Operational wavelength'};
            Variables = {'GaindB'; 'Fn'; 'lamb'};
            Values = {self.GaindB; self.Fn; self.lamb*1e9};
            Units = {'dB'; 'dB'; 'nm'};

            SOAtable = table(Variables, Values, Units, 'RowNames', rows);
        end
        
        %% Get methods
        function N0 = get.N0(obj)
            %% ASE noise one-sided power spectrum density per polarization
            % assumming Gain >> 1
            Ssp = (obj.Gain - 1)*10^(obj.Fn/10)/2*(obj.h*obj.c/obj.lamb); % Agrawal 6.1.15 3rd edition
            
            N0 = 2*Ssp; % one-sided baseband equivalent of Ssp
        end
        
        function GaindB = get.GaindB(obj)
            %% Gain in dB
            GaindB = 10*log10(obj.Gain); 
        end
        
        %% Set methods
        function this = set.GaindB(this, GdB)
            this.Gain = 10^(GdB/10); % set Gain, since GaindB is dependent
        end
    end
    
    %% Main Methods
    methods
        function sig2 = var_awgn(this, Plevel, Deltaf, Deltafopt, Npol)
            warning('soa/var_awgn: use varAWGN instead')
            sig2 = this.varAWGN(Plevel, Deltaf, Deltafopt, Npol);
        end
        function sig2 = varAWGN(this, Plevel, Deltaf, Deltafopt, Npol)
            %% Noise variance using AWGN approximation
            % - Plevel = power before amplifier
            % - Deltaf = Noise bandwidth of electric filter
            % - Deltafopt = Noise bandwidth of optical filter (!! bandpass filter)
            % - Npol = Number of noise polarizations. Default Npol = 1
            % !! Note: Responsivity is assumed to be 1. For different
            % responsivity make sig2 = R^2*sig2
            if exist('Npol', 'var') % default Noise polarizations = 1
                Npol = 1;
            end
            % Signal-Spontaneous beat noise + Spont-Spont beat noise
            % Agrawal 6.5.7 and 6.5.8 -- 3rd edition
            sig2 = 2*this.Gain*Plevel*this.N0*Deltaf + 1/2*Npol*this.N0^2*Deltafopt*Deltaf;
            % Note 1: N0 = 2Ssp
            % Note 2: Responsivity is assumed to be 1. For different
            % responsivity make sig2 = R^2*sig2
        end
       
        function [Eout, OSNRdB] = amp(obj, Ein, fs)
            %% Amplification
            % - Ein = received electric field (must be a N x 1 or 2 matrix
            % depending on number of polarizations)
            % - fs = sampling frequency     
            % Ouptuts:
            % - output: amplified signal
            % - OSNRdB: OSNR in 0.1nm in dB
            
            if size(Ein, 1) == 1 % 1 pol
                Ein = [Ein; zeros(size(Ein))];
            end
            
            dims = size(Ein);
            
            % N0 is the psd per polarization
            W = sqrt(1/2*obj.N0*fs/2)*(randn(dims) + 1j*randn(dims));
            % Note: soa.N0 is one-sided baseband equivalent of ASE PSD.
            % Thus we multiply by sim.fs/2
            
            Eout = sqrt(obj.Gain)*Ein + W;
            
            [~, Ps] = power_meter(Ein);
            
            % Estimate OSNR
            OSNRdB = 10*log10(obj.Gain*Ps/(obj.N0*obj.BWref))
        end      
    end
end