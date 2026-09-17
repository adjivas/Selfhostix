"""
Test the item download permalink endpoint in drive's core app.
"""

import pytest
from rest_framework.test import APIClient

from core import factories, models
from core.tests.conftest import TEAM, USER, VIA

pytestmark = pytest.mark.django_db


def test_api_items_download_anonymous_public():
    """Anonymous users should be redirected when the item is public."""
    item = factories.ItemFactory(
        link_reach="public",
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.READY,
    )

    response = APIClient().get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 302
    assert item.filename in response["Location"]
    assert f"item/{item.pk!s}" in response["Location"]


@pytest.mark.parametrize("reach", ["authenticated", "restricted"])
def test_api_items_download_anonymous_authenticated_or_restricted(reach):
    """
    Anonymous users should not be allowed to download items with link reach
    set to authenticated or restricted.
    """
    item = factories.ItemFactory(
        link_reach=reach,
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.READY,
    )

    response = APIClient().get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 401


@pytest.mark.parametrize("reach", ["public", "authenticated"])
def test_api_items_download_authenticated_public_or_authenticated(reach):
    """
    Authenticated users without explicit access to a public or authenticated item
    should be redirected to the media URL.
    """
    item = factories.ItemFactory(
        link_reach=reach,
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.READY,
    )

    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 302
    assert item.filename in response["Location"]


def test_api_items_download_authenticated_restricted():
    """
    Authenticated users without explicit access to a restricted item
    should not be allowed to download it.
    """
    item = factories.ItemFactory(
        link_reach="restricted",
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.READY,
    )

    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 403


@pytest.mark.parametrize("via", VIA)
@pytest.mark.parametrize(
    "upload_state",
    [
        models.ItemUploadStateChoices.READY,
        models.ItemUploadStateChoices.ANALYZING,
        models.ItemUploadStateChoices.FILE_TOO_LARGE_TO_ANALYZE,
    ],
)
def test_api_items_download_related(via, mock_user_teams, upload_state):
    """
    Users with explicit access to an item should be redirected to the media URL.
    """
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(
        type=models.ItemTypeChoices.FILE,
        update_upload_state=upload_state,
    )
    if via == USER:
        factories.UserItemAccessFactory(item=item, user=user)
    elif via == TEAM:
        mock_user_teams.return_value = ["lasuite", "unknown"]
        factories.TeamItemAccessFactory(item=item, team="lasuite")

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 302
    assert item.filename in response["Location"]
    assert f"item/{item.pk!s}" in response["Location"]


def test_api_items_download_redirect_url_stable_after_rename():
    """
    The download permalink URL must remain valid after an item is renamed.
    The redirect target should point to the current filename.
    """
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(
        type=models.ItemTypeChoices.FILE,
        filename="original_name.pdf",
        update_upload_state=models.ItemUploadStateChoices.READY,
        users=[(user, models.RoleChoices.EDITOR)],
    )

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")
    assert response.status_code == 302
    assert "original_name.pdf" in response["Location"]

    # Simulate a rename by updating the filename directly
    item.filename = "renamed_file.pdf"
    item.save()

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")
    assert response.status_code == 302
    assert "renamed_file.pdf" in response["Location"]
    assert "original_name.pdf" not in response["Location"]


def test_api_items_download_item_not_a_file():
    """Folders should not be downloadable via the permalink endpoint."""
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(type=models.ItemTypeChoices.FOLDER)
    factories.UserItemAccessFactory(item=item, user=user)

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 403


def test_api_items_download_item_pending():
    """Pending items (upload not complete) should not be downloadable."""
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(
        type=models.ItemTypeChoices.FILE,
        upload_state=models.ItemUploadStateChoices.PENDING,
    )
    factories.UserItemAccessFactory(item=item, user=user)

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 403


def test_api_items_download_suspicious_item_non_creator():
    """
    Users who are not the creator of a suspicious item should not be able
    to download it via the permalink endpoint.
    """
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.SUSPICIOUS,
        users=[(user, models.RoleChoices.OWNER)],
    )

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 404


def test_api_items_download_suspicious_item_creator():
    """
    The creator of a suspicious item should be redirected when downloading
    via the permalink endpoint.
    """
    user = factories.UserFactory()
    client = APIClient()
    client.force_login(user)

    item = factories.ItemFactory(
        creator=user,
        type=models.ItemTypeChoices.FILE,
        update_upload_state=models.ItemUploadStateChoices.SUSPICIOUS,
        users=[(user, models.RoleChoices.OWNER)],
    )

    response = client.get(f"/api/v1.0/items/{item.pk}/download/")

    assert response.status_code == 302
    assert item.filename in response["Location"]
