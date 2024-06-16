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

    public fun close_contribute(_: &AdminCap, self: &mut Contribution) {
        self.status = false;
    } 

    // action to cancel a contribution
    public fun cancel_contribution(
        self: &mut Contribution,
        milestone: Milestone,
        ctx: &mut TxContext,
    ) : Coin<SUI> {
        let Milestone {
            id,
            to: to,
            amount: amount_,
        } = milestone;
        assert!(object::uid_to_inner(&self.id) == to, EInvalidCancellationRequest);
        assert!(self.status, EMilestoneAlreadyCompleted);
        // Update milestone collected amount
        self.amount = self.amount - amount_;
        
        object::delete(id);

        let coin = coin::take(&mut self.balance, amount_, ctx);
        coin
    }

    // Withdraw amount for a milestone in contribution
    public fun withdraw_amount(
        _: &AdminCap,
        self: &mut Contribution,
        amount: u64,
        ctx: &mut TxContext,
    ) : Coin<SUI> {
        assert!(!self.status, EMilestoneAlreadyCompleted);
        self.amount = self.amount - amount;

        let coin_ = coin::take(&mut self.balance, amount, ctx);
        coin_
    }
}
