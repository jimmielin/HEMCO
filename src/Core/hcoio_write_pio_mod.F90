!BOC
#if defined(MODEL_CESM)
!EOC
!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: hcoio_write_pio_mod.F90
!
! !DESCRIPTION: Module HCOIO\_Write\_Mod is a stub for the HEMCO
! diagnostics output module in the CESM environment using PIO.
! Since diagnostic writing is handled by CAM's history infrastructure
! in CESM, this module provides a no-op implementation.
!\\
!\\
! !INTERFACE:
!
MODULE HCOIO_Write_Mod
!
! !USES:
!
  USE HCO_Types_Mod
  USE HCO_Error_Mod
  USE HCO_State_Mod, ONLY : Hco_State

  IMPLICIT NONE
  PRIVATE
!
! !PUBLIC MEMBER FUNCTIONS:
!
  PUBLIC :: HCOIO_Write
!
! !REVISION HISTORY:
!  08 Apr 2026 - H. Lin - Initial version (PIO stub)
!EOP
!------------------------------------------------------------------------------
!BOC
CONTAINS
!EOC
!------------------------------------------------------------------------------
!                   Harmonized Emissions Component (HEMCO)                    !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: HCOIO_Write
!
! !DESCRIPTION: Stub routine for HEMCO diagnostics output in CESM.
! In CESM, diagnostic output is handled by CAM's history infrastructure
! (cam\_history), so this routine is a no-op.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE HCOIO_Write( HcoState, ForceWrite, RC, &
                          PREFIX, UsePrevTime, OnlyIfFirst, COL )
!
! !INPUT PARAMETERS:
!
    TYPE(HCO_State),  POINTER                :: HcoState
    LOGICAL,          INTENT(IN   )          :: ForceWrite
    CHARACTER(LEN=*), INTENT(IN  ), OPTIONAL :: PREFIX
    LOGICAL,          INTENT(IN  ), OPTIONAL :: UsePrevTime
    LOGICAL,          INTENT(IN  ), OPTIONAL :: OnlyIfFirst
    INTEGER,          INTENT(IN  ), OPTIONAL :: COL
!
! !INPUT/OUTPUT PARAMETERS:
!
    INTEGER,          INTENT(INOUT)          :: RC
!
! !REVISION HISTORY:
!  08 Apr 2026 - H. Lin - Initial version (PIO stub)
!EOP
!------------------------------------------------------------------------------
!BOC

    ! No-op: diagnostics writing in CESM is handled by CAM history
    RC = HCO_SUCCESS

  END SUBROUTINE HCOIO_Write
!EOC
END MODULE HCOIO_Write_Mod
#endif
