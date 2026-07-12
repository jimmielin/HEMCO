!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: hco_directregrid_mod.F90
!
! !DESCRIPTION: Module HCO\_DirectRegrid\_Mod owns the "direct regrid" hook
!  through which a host model can regrid input data straight from each file's
!  native lat-lon grid onto the host's (possibly unstructured) model grid,
!  bypassing HEMCO's internal MAP\_A2A/MESSy regridding. This supports models
!  whose grids cannot be represented by HEMCO's rectilinear grid, e.g. the
!  CAM physics grid on regionally-refined spectral-element meshes.
!
!  HEMCO itself contains no regridding implementation for this mode: the host
!  registers its regridding routine (typically ESMF-based) at initialization
!  time via HCO\_DirectRegrid\_Register, and hcoio\_read\_pio\_mod.F90
!  dispatches to it through HCO\_DirectRegrid\_Run whenever HcoDirectMode is
!  enabled. This keeps HEMCO free of host dependencies (ESMF, physics-mesh
!  knowledge) while making the host-side contract explicit in a single
!  abstract interface owned by HEMCO.
!
!  Conventions expected of the registered routine:
!  \begin{itemize}
!  \item NcArr is the full global input array, replicated on every task
!        (as produced by pio\_get\_var), dimensioned (nlon,nlat,nlev,ntime).
!  \item LonEdge/LatEdge are the input grid edges (nlon+1 / nlat+1).
!  \item SigEdge holds the input sigma interface levels (nlon,nlat,nlev+1),
!        ordered surface (sigma~1) to top (sigma~0); it may be unassociated
!        for 2-D or single-level data.
!  \item Results are stored into Lct\%Dct\%Dta V2/V3 on the HcoState grid,
!        which in direct mode is the host column grid (NX=ncol, NY=1).
!  \end{itemize}
!
! !INTERFACE:
!
MODULE HCO_DirectRegrid_Mod
!
! !USES:
!
  USE HCO_Error_Mod
  USE HCO_State_Mod, ONLY : HCO_State
  USE HCO_Types_Mod, ONLY : ListCont

  IMPLICIT NONE
  PRIVATE
!
! !PUBLIC MEMBER FUNCTIONS:
!
  PUBLIC :: HCO_DirectRegrid_Register
  PUBLIC :: HCO_DirectRegrid_Reset
  PUBLIC :: HCO_DirectRegrid_Run
!
! !PUBLIC DATA:
!
  ! .TRUE. once a host has registered a direct regridding routine.
  ! Read by hcoio_read_pio_mod.F90 (regrid dispatch) and by
  ! hco_geotools_mod.F90 (point-source index lookup).
  LOGICAL, PUBLIC, SAVE :: HcoDirectMode = .FALSE.

  ! MPI communicator spanning all tasks that call HEMCO. Set by the host at
  ! registration time; used by collective operations that need global
  ! knowledge in direct mode (e.g. nearest-column ownership selection in
  ! HCO_GetHorzIJIndex, where the host grid is decomposed across tasks).
  INTEGER, PUBLIC, SAVE :: HcoDirectComm = -1
!
! !PUBLIC TYPES:
!
  ! Contract for the host-registered direct regridding routine.
  ABSTRACT INTERFACE
     SUBROUTINE HCO_DirectRegridFunc( HcoState, NcArr, LonEdge, LatEdge, &
                                      SigEdge,  Lct,   RC,      msg_out )
       IMPORT :: HCO_State, ListCont, sp, hp
       TYPE(HCO_State),            POINTER       :: HcoState
       REAL(sp),                   POINTER       :: NcArr(:,:,:,:)
       REAL(hp),                   POINTER       :: LonEdge(:)
       REAL(hp),                   POINTER       :: LatEdge(:)
       REAL(hp),                   POINTER       :: SigEdge(:,:,:)
       TYPE(ListCont),             POINTER       :: Lct
       INTEGER,                    INTENT(INOUT) :: RC
       CHARACTER(LEN=*), OPTIONAL, INTENT(  OUT) :: msg_out
     END SUBROUTINE HCO_DirectRegridFunc
  END INTERFACE
!
! !REVISION HISTORY:
!  10 Jul 2026 - H.P. Lin - Initial version, replacing the implicit dependency
!                           of hcoio_read_pio_mod.F90 on a host-side module.
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !PRIVATE TYPES:
!
  PROCEDURE(HCO_DirectRegridFunc), POINTER, SAVE :: DirectRegridPtr => NULL()

CONTAINS
!EOC
!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: HCO_DirectRegrid_Register
!
! !DESCRIPTION: Registers the host model's direct regridding routine and
!  enables direct mode. To be called once by the host during initialization,
!  before the first HEMCO data read.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE HCO_DirectRegrid_Register( Func, mpiComm )
!
! !INPUT PARAMETERS:
!
    PROCEDURE(HCO_DirectRegridFunc)  :: Func     ! Host regridding routine
    INTEGER, OPTIONAL, INTENT(IN)    :: mpiComm  ! Host MPI communicator
!
! !REVISION HISTORY:
!  10 Jul 2026 - H.P. Lin - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
    DirectRegridPtr => Func
    HcoDirectMode   =  .TRUE.
    IF ( PRESENT(mpiComm) ) HcoDirectComm = mpiComm

  END SUBROUTINE HCO_DirectRegrid_Register
!EOC
!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: HCO_DirectRegrid_Reset
!
! !DESCRIPTION: Disables direct mode and forgets the registered routine.
!  To be called by the host during finalization so a finalize+re-init cycle
!  starts from a clean state.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE HCO_DirectRegrid_Reset()
!
! !REVISION HISTORY:
!  10 Jul 2026 - H.P. Lin - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
    DirectRegridPtr => NULL()
    HcoDirectMode   =  .FALSE.
    HcoDirectComm   =  -1

  END SUBROUTINE HCO_DirectRegrid_Reset
!EOC
!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: HCO_DirectRegrid_Run
!
! !DESCRIPTION: Dispatches one input field to the host-registered direct
!  regridding routine. Errors out if direct mode is enabled without a
!  registered routine.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE HCO_DirectRegrid_Run( HcoState, NcArr, LonEdge, LatEdge, &
                                   SigEdge,  Lct,   RC )
!
! !INPUT/OUTPUT PARAMETERS:
!
    TYPE(HCO_State),  POINTER       :: HcoState          ! HEMCO state object
    REAL(sp),         POINTER       :: NcArr(:,:,:,:)    ! Input data (global)
    REAL(hp),         POINTER       :: LonEdge(:)        ! Input lon edges
    REAL(hp),         POINTER       :: LatEdge(:)        ! Input lat edges
    REAL(hp),         POINTER       :: SigEdge(:,:,:)    ! Input sigma edges
                                                         !  (may be NULL)
    TYPE(ListCont),   POINTER       :: Lct               ! Target container
    INTEGER,          INTENT(INOUT) :: RC                ! Return code
!
! !REVISION HISTORY:
!  10 Jul 2026 - H.P. Lin - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
    CHARACTER(LEN=511)          :: MSG
    CHARACTER(LEN=*), PARAMETER :: LOC = &
       'HCO_DirectRegrid_Run (hco_directregrid_mod.F90)'

    IF ( .NOT. ASSOCIATED(DirectRegridPtr) ) THEN
       CALL HCO_ERROR( 'HcoDirectMode is enabled but no direct regridding'// &
                       ' routine was registered by the host model. Call'//   &
                       ' HCO_DirectRegrid_Register during initialization.',  &
                       RC, THISLOC=LOC )
       RETURN
    ENDIF

    MSG = ''
    CALL DirectRegridPtr( HcoState, NcArr, LonEdge, LatEdge, SigEdge, &
                          Lct, RC, msg_out=MSG )
    IF ( RC /= HCO_SUCCESS ) THEN
       CALL HCO_ERROR( 'Direct regridding failed: '//TRIM(MSG), &
                       RC, THISLOC=LOC )
       RETURN
    ENDIF

  END SUBROUTINE HCO_DirectRegrid_Run
!EOC
END MODULE HCO_DirectRegrid_Mod
