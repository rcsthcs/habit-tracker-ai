"""
Script to promote a user to admin.
Usage: python create_admin.py <username>
"""
import asyncio
import sys
from sqlalchemy import select, update
from app.db.database import engine, AsyncSessionLocal
from app.models.user import User


async def make_admin(username: str):
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.username == username))
        user = result.scalar_one_or_none()
        if not user:
            print(f"❌ User '{username}' not found")
            return
        if user.is_admin:
            print(f"ℹ️  User '{username}' is already an admin")
            return
        user.is_admin = True
        await db.commit()
        print(f"✅ User '{username}' is now an admin!")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python create_admin.py <username>")
        sys.exit(1)
    asyncio.run(make_admin(sys.argv[1]))


