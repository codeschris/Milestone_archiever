module milestone_management::milestone_management{

    use sui::event::{Self};
    use std::string::{Self,String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
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
    public struct Milestone has key, store {
        id: UID,
        to: ID,
        amount: u64
    }

    // Contribution struct
    public struct Contribution has key, store {
        id: UID,
        amount: u64,
        target_amount: u64,
        status: bool,
        balance: Balance<SUI>,
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

    public fun new_contribute(_:&AdminCap, milestone: ID, amount: u64, target_amount: u64, ctx: &mut TxContext) {
        transfer::share_object(Contribution {
            id: object::new(ctx),
            amount: amount,
            target_amount,
            status: true,
            balance: balance::zero(),
        });
    }

    // action to contribute to a milestone
    public fun contribute (
        self: &mut Contribution,
        coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) : Milestone {
        assert!(self.status, EMilestoneAlreadyCompleted);
        let amount = coin::value(&coin);

        let milestone = Milestone {
            id: object::new(ctx),
            to: object::id(self),
            amount: amount
        };
        coin::put(&mut self.balance, coin);
        self.amount = self.amount + amount;
        milestone
    }

    // // action to cancel a contribution
    // public entry fun cancel_contribution(
    //     milestone: &mut Milestone,
    //     contribution: Contribution,
    //     ctx: &mut TxContext,
    // ) {
    //     let Contribution {
    //         id,
    //         milestone_id,
    //         amount,
    //         balance,
    //         contributor,
    //     } = contribution;
    //     assert!(object::uid_to_inner(&milestone.id) == milestone_id, EInvalidCancellationRequest);
    //     assert!(milestone.status, EMilestoneAlreadyCompleted);
    //     // Update milestone collected amount
    //     milestone.collected_amount = milestone.collected_amount - amount;
    //     // Emit event
    //     let milestone_updated = MilestoneUpdated {
    //         milestone_id: object::uid_to_inner(&milestone.id),
    //         new_amount: milestone.collected_amount,
    //     };
    //     event::emit<MilestoneUpdated>(milestone_updated);

    //     object::delete(id);

    //     let coin_ = coin::from_balance(balance, ctx);
    //     transfer::public_transfer(coin_, tx_context::sender(ctx));
    // }

    // // Function to retrieve milestone status and collected amount
    // public fun get_milestone_status(
    //     milestone: &Milestone,
    // ): (u64) {
    //     (milestone.collected_amount)
    // }

    // // get balance of a contribution
    // public fun get_contribution_balance(
    //     contribution: &Contribution,
    // ) : &Balance<SUI> {
    //     &contribution.balance
    // }

    // // Withdraw amount for a milestone in contribution
    // public entry fun withdraw_amount(
    //     milestone: &mut Milestone,
    //     contribution: &mut Contribution,
    //     amount: u64,
    //     ctx: &mut TxContext,
    // ) {
    //     assert!(object::id(milestone) == contribution.milestone_id, EInvalidContributionAmount);
    //     assert!(!milestone.status, EMilestoneAlreadyCompleted);
    //     assert!(milestone.collected_amount >= amount, EInvalidContributionAmount);
    //     // Check for amount to withdraw not to exceed target amount of milestone
    //     assert!(milestone.target_amount >= amount, EAbsurdAmount);
    //     milestone.collected_amount = milestone.collected_amount - amount;

    //     // Emit event
    //     let milestone_updated = MilestoneUpdated {
    //         milestone_id: object::uid_to_inner(&milestone.id),
    //         new_amount: milestone.collected_amount,
    //     };
    //     event::emit<MilestoneUpdated>(milestone_updated);

    //     let withdraw_amount = coin::take(&mut contribution.balance,amount, ctx);
    //     transfer::public_transfer(withdraw_amount, tx_context::sender(ctx));
    // }
}
