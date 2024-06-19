module milestone_management::milestone_management {

    use sui::event::{Self};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext, sender};
    use sui::object::{Self, UID};
    use sui::transfer;

    /* Error Constants */
    const EWrongOwner: u64 = 0;
    const EAbsurdAmount: u64 = 1;
    const EInvalidContributionAmount: u64 = 2;
    const EMilestoneAlreadyCompleted: u64 = 3;
    const EInvalidCancellationRequest: u64 = 5;

    /* Structs */
    // Admin capability struct, representing the ability to create and manage milestones
    public struct AdminCap has key {
        id: UID
    }

    // Milestone struct, representing a milestone with specific targets and collected amounts
    public struct Milestone has key {
        id: UID,
        description: String,
        target_amount: u64,
        collected_amount: u64,
        status: String,
        owner: address,
    }

    // Contribution struct, representing a contribution towards a milestone
    public struct Contribution has key, store {
        id: UID,
        milestone_id: UID,
        amount: u64,
        balance: Balance<SUI>,
        contributor: address,
    }

    // MilestoneUpdated event struct, representing updates to a milestone
    public struct MilestoneUpdated has copy, drop {
        milestone_id: UID,
        new_amount: u64,
        status: String,
    }

    /* Functions */

    // Initializes the module by creating an AdminCap and transferring it to the sender
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    // Function to create milestones, restricted to admin capability
    public entry fun create_milestone(
        _: &AdminCap,
        description: vector<u8>,
        target_amount: u64,
        ctx: &mut TxContext,
    ) {
        let milestone = Milestone {
            id: object::new(ctx),
            description: string::utf8(description),
            target_amount,
            collected_amount: 0,
            status: string::utf8(b"Open"),
            owner: tx_context::sender(ctx),
        };
        transfer::share_object(milestone);
    }

    // Function to contribute to a milestone
    public entry fun contribute (
        milestone: &mut Milestone,
        amount: u64,
        collateral: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        // Ensures that the contribution amount is greater than zero
        assert!(amount > 0, EInvalidContributionAmount);

        // Ensures that contributions can only be made to open milestones
        assert!(milestone.status == string::utf8(b"Open"), EMilestoneAlreadyCompleted);

        let contribution_id = object::new(ctx);
        let contribution = Contribution {
            id: contribution_id,
            milestone_id: milestone.id,
            amount,
            balance: coin::into_balance(collateral),
            contributor: tx_context::sender(ctx),
        };

        // Updates the collected amount of the milestone
        milestone.collected_amount = milestone.collected_amount + amount;

        // Check if the milestone is fully funded
        if (milestone.collected_amount >= milestone.target_amount) {
            milestone.status = string::utf8(b"Completed");
        }

        // Emit event to log the milestone update
        let milestone_updated = MilestoneUpdated {
            milestone_id: milestone.id,
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        transfer::share_object(contribution);
    }

    // Function to cancel a contribution
    public entry fun cancel_contribution(
        milestone: &mut Milestone,
        contribution: Contribution,
        ctx: &mut TxContext,
    ) {
        // Ensure the caller is the contributor of the contribution
        assert!(contribution.contributor == tx_context::sender(ctx), EWrongOwner);

        // Ensure the contribution belongs to the given milestone
        assert!(contribution.milestone_id == milestone.id, EInvalidCancellationRequest);

        // Ensure the milestone is not already completed
        assert!(milestone.status != string::utf8(b"Completed"), EMilestoneAlreadyCompleted);

        // Update the milestone's collected amount
        milestone.collected_amount = milestone.collected_amount - contribution.amount;

        // If the milestone was marked as completed, revert its status to open if the contribution is canceled
        if (milestone.status == string::utf8(b"Completed")) {
            milestone.status = string::utf8(b"Open");
        }

        // Emit event to log the milestone update
        let milestone_updated = MilestoneUpdated {
            milestone_id: milestone.id,
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        // Delete the contribution object
        object::delete(contribution.id);

        // Transfer the collateral back to the contributor
        let refund = coin::from_balance(contribution.balance, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));
    }

    // Function to retrieve the status and collected amount of a milestone
    public fun get_milestone_status(
        milestone: &Milestone,
    ): (u64, String) {
        (milestone.collected_amount, milestone.status.clone())
    }

    // Function to get the balance of a contribution
    public fun get_contribution_balance(
        contribution: &Contribution,
    ) : &Balance<SUI> {
        &contribution.balance
    }

    // Function to withdraw an amount from a milestone contribution
    public entry fun withdraw_amount(
        milestone: &mut Milestone,
        contribution: &mut Contribution,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        // Ensure the caller is the owner of the milestone
        assert!(tx_context::sender(ctx) == milestone.owner, EWrongOwner);

        // Ensure the milestone is marked as completed before withdrawal
        assert!(milestone.status == string::utf8(b"Completed"), EMilestoneAlreadyCompleted);

        // Ensure the collected amount is sufficient for the withdrawal
        assert!(milestone.collected_amount >= amount, EInvalidContributionAmount);

        // Ensure the amount to withdraw does not exceed the target amount
        assert!(milestone.target_amount >= amount, EAbsurdAmount);

        // Update the collected amount after withdrawal
        milestone.collected_amount = milestone.collected_amount - amount;

        // Emit event to log the milestone update
        let milestone_updated = MilestoneUpdated {
            milestone_id: milestone.id,
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        // Withdraw the specified amount from the contribution balance and transfer to the milestone owner
        let withdraw_amount = coin::take(&mut contribution.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, tx_context::sender(ctx));
    }

}
