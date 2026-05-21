а """Add cashback_rate and transactions_count to bonus_cards

Revision ID: 001
Revises: 
Create Date: 2026-05-21
"""
from alembic import op
import sqlalchemy as sa

revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'bonus_cards',
        sa.Column('cashback_rate', sa.Numeric(5, 2), nullable=False, server_default='3.00'),
    )
    op.add_column(
        'bonus_cards',
        sa.Column('transactions_count', sa.Integer(), nullable=False, server_default='0'),
    )


def downgrade() -> None:
    op.drop_column('bonus_cards', 'transactions_count')
    op.drop_column('bonus_cards', 'cashback_rate')