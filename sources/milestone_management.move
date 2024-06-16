module milestone_management::milestone_management{

    use sui::event::{Self};
    use std::string::{Self,String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::sui::SUI;

   /* Error Constants */
    const EWrongOwner: u64 = 0;
    const EAbsurdAmount: u64 = 1;
    const EInvalidContributionAmount: u64 = 2;
    const EMilestoneAlreadyCompleted: u64 = 3;
    const EInvalidCancellationRequest: u64 = 5;


     /* Structs */
    // Admin capability struct
    public struct AdminCap has key {
        id: UID
    }

    // Milestone struct
    public struct Milestone has key {
        id: UID,
        description: String,
        target_amount: u64,
        collected_amount: u64,
        status: bool,
    }

    // Contribution struct
    public struct Contribution has key, store {
        id: UID,
        milestone_id: ID,
        amount: u64,
        balance: Balance<SUI>,
        contributor: address,
    }

    // Milestone updated event
    public struct MilestoneUpdated has copy, drop {
        milestone_id: ID,
        new_amount: u64,
    }

      /* Functions */
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }
    // Function where  admin is one who  can create milestones
    public entry fun create_milestone(
        _: &AdminCap,
        description: String,
        target_amount: u64,
        ctx: &mut TxContext,
    ) {
        let milestone = Milestone {
            id: object::new(ctx),
            description: description,
            target_amount,
            collected_amount: 0,
            status: true,
        };
        transfer::share_object(milestone);
    }

    // action to contribute to a milestone
    public fun contribute (
        milestone: &mut Milestone,
        collateral: Coin<SUI>,
        ctx: &mut TxContext,
    ) : Contribution {
        assert!(milestone.status, EMilestoneAlreadyCompleted);
        let amount = coin::value(&collateral);

        let id_ = object::new(ctx);
        let _inner_ = object::uid_to_inner(&id_);
        let contribution = Contribution {
            id: id_,
            milestone_id: object::uid_to_inner(&milestone.id),
            amount,
            balance: coin::into_balance(collateral),
            contributor: tx_context::sender(ctx),
        };
        milestone.collected_amount = milestone.collected_amount + amount;
        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
        };
        event::emit<MilestoneUpdated>(milestone_updated);
        contribution
    }

    // action to cancel a contribution
    public entry fun cancel_contribution(
        milestone: &mut Milestone,
        contribution: Contribution,
        ctx: &mut TxContext,
    ) {
        let Contribution {
            id,
            milestone_id,
            amount,
            balance,
            contributor,
        } = contribution;
        assert!(object::uid_to_inner(&milestone.id) == milestone_id, EInvalidCancellationRequest);
        assert!(milestone.status, EMilestoneAlreadyCompleted);
        // Update milestone collected amount
        milestone.collected_amount = milestone.collected_amount - amount;
        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        object::delete(id);

        let coin_ = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin_, tx_context::sender(ctx));
    }

    // Function to retrieve milestone status and collected amount
    public fun get_milestone_status(
        milestone: &Milestone,
    ): (u64) {
        (milestone.collected_amount)
    }

    // get balance of a contribution
    public fun get_contribution_balance(
        contribution: &Contribution,
    ) : &Balance<SUI> {
        &contribution.balance
    }

    // Withdraw amount for a milestone in contribution
    public entry fun withdraw_amount(
        milestone: &mut Milestone,
        contribution: &mut Contribution,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(!milestone.status, EMilestoneAlreadyCompleted);
        assert!(milestone.collected_amount >= amount, EInvalidContributionAmount);
        // Check for amount to withdraw not to exceed target amount of milestone
        assert!(milestone.target_amount >= amount, EAbsurdAmount);
        milestone.collected_amount = milestone.collected_amount - amount;

        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        let withdraw_amount = coin::take(&mut contribution.balance,amount, ctx);
        transfer::public_transfer(withdraw_amount, tx_context::sender(ctx));
    }
}
