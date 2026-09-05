"""Emergency assistance API routes — consumer facing."""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.emergency import EmergencyRequestCreate, EmergencyRequestResponse
from app.services.emergency_service import emergency_service

router = APIRouter()


@router.get("/mine", response_model=list[EmergencyRequestResponse])
def list_my_emergency_requests(
    user: AuthenticatedUser = Depends(get_current_user),
) -> list[EmergencyRequestResponse]:
    """Get all emergency requests for the current consumer.

    Requires authentication. Consumers can only view their own requests.
    """
    return emergency_service.get_my_requests(user.user_id)


@router.get("/{request_id}", response_model=EmergencyRequestResponse)
def get_emergency_request(
    request_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> EmergencyRequestResponse:
    """Get details of a specific emergency request.

    Requires authentication. Consumers can only view their own requests.
    """
    return emergency_service.get_request(request_id)


@router.post("", response_model=EmergencyRequestResponse, status_code=201)
def create_emergency_request(
    data: EmergencyRequestCreate,
    user: AuthenticatedUser = Depends(get_current_user),
) -> EmergencyRequestResponse:
    """Create a new emergency energy assistance request.

    Requires authentication. Only consumers can submit emergency requests.
    The request will be reviewed by an administrator.
    """
    consumer_name = user.email or "Consumer"
    return emergency_service.create_request(user.user_id, consumer_name, data)
